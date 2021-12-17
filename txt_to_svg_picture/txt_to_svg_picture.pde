import geomerative.*;
import processing.pdf.*;

public enum CutMode {
  LASER_CUTTING,
  MILLING,
};

// ---------- PER-SONG PARAMS ----------
// Change these to match your files and cut type
String song_data_filename = "time_you_and_i.txt";
String shape_filename = "flow-field-crop.svg";
CutMode mode = CutMode.MILLING;
boolean split_pdfs = false;            // Set to true to create multiple files w/ pieces of image instead of one monster. Useful for illustrator or some laser cutters that barf on files w/ ton of vertices in it
// ---------- END PER-SONG PARAMS ---------


// ---------- CONSTANTS ----------
static int PX_PER_IN = 72;                  // Scale factor of vectors, default 72 dpi (not sure about this one)
static float mill_tip_diameter_in = 0.06;
static float mill_tip_diameter_px = mill_tip_diameter_in * PX_PER_IN;

// Milling
static float milling_waveform_amplitude_pixels = 40.0;
static int milling_width_in = 24;
static int milling_height_in = 24;
static float milling_stroke_weight = mill_tip_diameter_px;
static float milling_distance_between_points = -1;    // unused for milling
static int milling_long_jump_threshold_px = PX_PER_IN;

// Laser cutting
static float laser_cutting_waveform_amplitude_pixels = 5.0;
static int laser_cutting_width_in = 12;
static int laser_cutting_height_in = 12;
static float laser_cutting_stroke_weight = 0.3;
static float laser_cutting_distance_between_points = 0.3;
static int laser_cutting_long_jump_threshold_px = 5;
// ---------- END CONSTANTS ----------


// ---------- INTERNAL PARAMS ----------
// Don't touch these, needed to maintain state between iterations of loop()
// Shared constants set from milling or laser cutting constants
float waveform_amplitude_pixels; // Total amplitude of audio waveform to scale to
int width_in;
int height_in;
float stroke_weight;
float distance_between_points;
int long_jump_threshold_px;

// Output files
String base_filename;
int files_created = 0;

// Song data
float song_data[] = new float[] {};
int song_data_increment;
int song_data_size;
int song_data_index = 0;

// SVG shape data
RPoint [] points_full;                                  // Holds full array of points received from rshape parse of svg
ArrayList<RPoint> points = new ArrayList<RPoint>();    // Holds array of points that we'll use plotting. This is identical to points_full for lasercutting, but has points removed for milling
int points_index = 0;
int points_size;    // Number of plottable points after milling or interpolation adjustment
int total_points_to_plot = 0;
// ---------- END INTERNAL GLOBALS ----------


void setup () {
  switch (mode) {
    case LASER_CUTTING:
      waveform_amplitude_pixels = laser_cutting_waveform_amplitude_pixels;
      width_in = laser_cutting_width_in;
      height_in = laser_cutting_height_in;
      stroke_weight = laser_cutting_stroke_weight;
      distance_between_points = laser_cutting_distance_between_points;
      long_jump_threshold_px = laser_cutting_long_jump_threshold_px;
      break;
    case MILLING:
      waveform_amplitude_pixels = milling_waveform_amplitude_pixels;
      width_in = milling_width_in;
      height_in = milling_height_in;
      stroke_weight = milling_stroke_weight;
      distance_between_points = milling_distance_between_points;
      long_jump_threshold_px = milling_long_jump_threshold_px;
      break;
  }
  
  // Have to do this bs because you can't pass non-constants to size()
  // Normally we would calc width_px/height_px by multiplying width_in * PX_PER_IN
  // If you change the values in the asserts, recalculate the values in size() manually
  if (mode == CutMode.MILLING) {
    println("In MILLING mode, make sure you've manually set the size(x, y) call to size(" + (width_in * PX_PER_IN) + ", " + (height_in * PX_PER_IN) + ")");
  } else {
    println("In LASER_CUTTING mode, make sure you've manually set the size(x, y) call to size(" + (width_in * PX_PER_IN) + ", " + (height_in * PX_PER_IN) + ")");
  }

  // Processing doesn't even let you put two size() calls in two separate if-blocks
  //so this one needs to be hand-changed every switch to/from milling/lasercutting mode
  assert(width_in == 24);
  assert(height_in == 24);
  size(1728, 1728);
  //assert(width_in == 12);
  //assert(height_in == 12);
  //size(864, 864);
  
  // Pull in song data in txt form and normalize it
  // Intake csv text, tranform to floats and normalize based on max value and waveform amplitude setting
  song_data = process_audio_text_file(song_data_filename);
  song_data_size = song_data.length;
  
  // Pull in points from base image .svg
  RG.init(this);
  RShape svg_shape = RG.loadShape(shape_filename);
  
  // Scales the svg to the correct width/height, 12in x 12in.
  // This assumes that the input .svg is square already. If not, it
  // will scale the longest edge to 12in but still retain aspect ratio
  float shape_height = svg_shape.getHeight();
  float shape_width = svg_shape.getWidth();
  float max_side_length = shape_height > shape_width ? shape_height : shape_width;
  if (shape_height != shape_width) {
    println("WARNING: input svg not square, scaling max side length of " + max_side_length + "px to canvas side length of " + (width_in * PX_PER_IN) + "px");
  }
  
  // width_in * PX_PER_IN is scaling to same value we passed into size(x,y) at the beginning of setup()
  svg_shape.scale((width_in * PX_PER_IN) / max_side_length);
  
  RG.setPolygonizerLength(1);
  points_full = svg_shape.getPoints();
  
  // Count up how many points we'll plot in this design so we can skip the correct number of song data points each subsequent point plot
  if (mode == CutMode.MILLING) {
    // There is zero interpolation that happens in milling mode - we take points OUT of the shape data to make sure stuff is spaced out enough
    // TODO :: remove points intelligently based on point-to-point distance instead of just yanking points every X initial points
    for (int i = 0; i < points_full.length; i += 2) {
       points.add(points_full[i]); 
    }
    
    total_points_to_plot = points.size();
  } else {
    // Add every point received from shape to points_full. Loop calculations are to determine how many
    // total points will be plotted with varying interpolation sizes. points_full used for logic/access
    // since linear array access is faster
    for (int i = 0; i < points_full.length - 1; i++) {
      // Add to main points array before anything else
      RPoint point = points_full[i];
      points.add(point);
      float x = point.x;
      float y = point.y;
      if (x == 0 || y == 0 || x == width || y == height) {
        continue;
      }
      
      float next_x = points_full[i + 1].x;
      float next_y = points_full[i + 1].y;
      float point_distance = distance_between_points(next_x, next_y, x, y);
  
      // Skip the larger distances we'll do jumps for in the draw loop
      if (point_distance <= 5) {
        total_points_to_plot += (int)Math.floor(point_distance / distance_between_points);
      }
    }
  }
 
  points_size = points.size();
  println("Total points from RShape:  " + points_full.length);
  println("Actual total plottable points after " + (mode == CutMode.MILLING ? "removing shape data points: " : "dynamic interpolation based on 'distance_between_points': ") + total_points_to_plot);
  println("Total count of song data points: " + song_data_size);
  assert(song_data_size >= total_points_to_plot);

  song_data_increment = (int)Math.floor(song_data_size / total_points_to_plot);
  println("Skipping every " + song_data_increment + " song data points to fit in available plottable points");
  
  base_filename = song_data_filename.substring(0, song_data_filename.lastIndexOf('.')) + "_" + shape_filename.substring(0, shape_filename.lastIndexOf('.')) + "_line_following_";
  beginRecord(PDF, base_filename + (files_created++) + ".pdf");
  println("Created initial file '" + base_filename + (files_created - 1) + ".pdf'");
  background(255);
  beginShape();
  stroke(0);
  strokeWeight(stroke_weight);
  noFill();
  
  // Assume border (if there is one) is all in front of array. Pre-incrementing our points_index
  // to the start of the real data here lets us avoid an if-check every point increment in the loop below.
  // If no border, we lose the first point (meh)
  float x;
  float y;
  do {
    x = points.get(points_index).x;
    y = points.get(points_index).y;
    points_index++;    
  } while (x <= 5 || y <= 5 || x >= (width - 5) || y >= (height - 5));
  println("Starting to plot song_data at first non-border points_index is " + points_index + " holding (x,y) coord of (" + x + ", " + y + ")");
}

void draw() {
  // If we've finished the shape or points_index is negative (?), bail
  if (points_index + 1 >= points_size || points_index < 0) {
    //if (points_index > 3000) {
    finishAndExit();
    return;
  };
  
  float x = points.get(points_index).x;
  float y = points.get(points_index).y;
  float next_x = points.get(points_index + 1).x;
  float next_y = points.get(points_index + 1).y;
  float point_distance = distance_between_points(next_x, next_y, x, y);

  // "Raise the pen" and move to the next point if we're about to make a big jump,
  // meaning our next point isn't on the continuous line of the originally drawing.
  // Otherwise we get big lines all across the drawing.
  if (point_distance > long_jump_threshold_px) {
    vertex(x, y);
    endShape();
    beginShape();
    points_index++;
    
    return;
  }
  
  // Chunk up vectors, processing can only do so many points in one shape.
  int actual_vertices_drawn = song_data_index / song_data_increment;
  if (actual_vertices_drawn % 2000 == 0 && song_data_index != 0) {
    //println("Switching to new shape at points_index " + points_index + ", song data index " + song_data_index + ", and actual vertices drawn " + actual_vertices_drawn);
    endShape();
    
    if (split_pdfs && actual_vertices_drawn % 300000 == 0 && song_data_index != 0) {
      int percent_drawn = (actual_vertices_drawn / (total_points_to_plot)) * 100;
      println("New file " + base_filename + (files_created) + ".pdf at " + percent_drawn + "% of plottable points plotted");
      endRecord();
      beginRecord(PDF, base_filename + (files_created++) + ".pdf");
      background(255);
      beginShape();
      stroke(0);
      strokeWeight(stroke_weight);
      noFill();
    }
    beginShape();
    
    // TODO don't leave a one segment gap
    //vertex(prev_x, prev_y);
  }
  
  // Compute the angle from this point to the next for line interp going forward
  // instead of angle from prev point to here
  float diff_x = next_x - x;
  float diff_y = -1 * (next_y - y);
  float angle = atan2(diff_y, diff_x);

  int num_interpolated_points;
  if (mode == CutMode.MILLING) {
    // Plot a single point right at the actual coordinates for milling. We never interpolate when milling.
    num_interpolated_points = 1;
  } else {
    // An extra bounds checkto make sure this set of interpolated points between two coords won't put us over our song data size.
    // Have to check instead of including in initial draw() bounds checks because we don't know num_interpolated_points until now
    num_interpolated_points = (int)Math.floor(point_distance / distance_between_points);
    if (song_data_index + num_interpolated_points * song_data_increment > song_data_size) {
      finishAndExit();
      return;
    }
  }
  
  // Interpolate the line between the two points given to us from the RShape to pack sound data tighter.
  // In theory this should be constant but the points generated by RShape are not alwasys spaced uniformly.
  float x_step_length = diff_x / num_interpolated_points;
  float y_step_length = diff_y / num_interpolated_points;
  for (int i = 0; i < num_interpolated_points; i++) {
    // Base point (x/y) + the interpolated distance straight on the line to the next point + 
    // the song data x/y normalized to the overall angle between RShape points    
    float adj_x = x + (i * x_step_length) + (song_data[song_data_index] * sin(angle));
    float adj_y = y - (i * y_step_length) + (song_data[song_data_index] * cos(angle));
    
    vertex(adj_x, adj_y);
    song_data_index += song_data_increment;
  }

  points_index++;
}

float[] process_audio_text_file(String input_filename) {
    // Load full comma-delimited file - no line breaks so just grab the first index for everthing
    String raw_string_data_array[] = loadStrings(input_filename);
    String raw_string_data  = raw_string_data_array[0];
    float audio_data[] = float(split(raw_string_data, ','));

    // Grab max value of waveform
    float max_audio_value = audio_data[0];
    for (int i = 1; i < audio_data.length; i++) {
        float current_value_positive = abs(audio_data[i]);
        if (current_value_positive > max_audio_value) {
            max_audio_value = audio_data[i];
        }
    }

    // Normalize audio to given amplitude
    for (int i = 0; i < audio_data.length; i++) {
        audio_data[i] *= (waveform_amplitude_pixels / max_audio_value);
    }

    return audio_data;
}

// Rough - rounds off the decimal. Only used for large point jumps to keep from drawing lines across whole image
float distance_between_points(float x, float y, float prev_x, float prev_y) {
  return sqrt((x - prev_x) * (x - prev_x) + (y - prev_y) * (y - prev_y));
}

void finishAndExit() {
    println("Made it " + ((float)(song_data_index * 100) / song_data_size) + "% through song data");
    endShape();
    endRecord();
    exit();
}
