import geomerative.*;
import processing.pdf.*;

public enum CutMode {
  LASER_CUTTING,
  MILLING,
};

static int PX_PER_IN = 72;                  // Scale factor of vectors, default 72 dpi (not sure about this one)
static float mill_tip_diameter_in = 0.06;
static float mill_tip_diameter_px = mill_tip_diameter_in * PX_PER_IN;

// ---------- PER-SONG PARAMS ----------

String song_data_filename = "time_you_and_i.txt";
String shape_filename = "flow-field-crop.svg";
CutMode mode = CutMode.MILLING;
boolean split_pdfs = false;            // Set to true to create multiple files w/ pieces of image instead of one monster. Useful for illustrator or some laser cutters that barf on files w/ ton of vertices in it

static int song_data_increment = 50;        // Number of indexes to skip ahead for each song_data point we pull (full array can be in tens of millions)
static float stroke_weight = 0.2;            // Thickness of line
boolean split_pdfs = false;            // Set to true to create multiple files w/ pieces of image instead of one monster. Useful for illustrator or some laser cutters that barf on files w/ ton of vertices in it

// ---------- END PER-SONG PARAMS ---------

// ---------- INTERNAL GLOBALS ----------
// Don't touch these, needed to maintain state between iterations of loop()

String base_filename;
int files_created = 0;

static float laser_cutting_waveform_amplitude_pixels = 5.0;
static float milling_waveform_amplitude_pixels = 40.0;
float waveform_amplitude_pixels; // Total amplitude of audio waveform to scale to

static int milling_width_in = 24;
static int milling_height_in = 24;
static int laser_cutting_width_in = 12;
static int laser_cutting_height_in = 12;
static int width_in;
static int height_in;

float song_data[] = new float[] {};
int song_data_increment;
int song_data_size;
RPoint [] points_full;
ArrayList<RPoint> points = new ArrayList<RPoint>();

//float song_data[] = new float[song_data_size];
int points_index = 0;                      // Start with second point to pre-calc the diffs'
int song_data_index = points_index;
int x_sign;
int y_sign;

// ---------- END INTERNAL GLOBALS ----------

void setup () {
  switch (mode) {
    case LASER_CUTTING:
      waveform_amplitude_pixels = laser_cutting_waveform_amplitude_pixels;
      width_in = laser_cutting_width_in;
      height_in = laser_cutting_height_in;
      break;
    case MILLING:
      waveform_amplitude_pixels = milling_waveform_amplitude_pixels;
      width_in = milling_width_in;
      height_in = milling_height_in;
      break;
  }
  
  // Have to do this bs because you can't pass non-constants to size()
  // Normally we would calc width_px/height_px by multiplying width_in * PX_PER_IN
  // If you change the values in the asserts, recalculate the values in size() manually
  assert(width_in == 24);
  assert(height_in == 24);
  //size(2592, 1728);
  size(1728, 1728); 

  
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
  
  // width_in * PX_PER_IN is scaling to same value we passed into size(x,y) at the beginning of setup()
  svg_shape.scale((width_in * PX_PER_IN) / max_side_length);
  
  RG.setPolygonizerLength(1);
  //points = svg_shape.getPoints();
  points_full = svg_shape.getPoints();
  
  for (int i = 0; i < points_full.length; i += 3) {
     points.add(points_full[i]); 
  }
  
  println("Total points from RShape:  " + points.size());
  println("Total points to print shape after interpolation: " + points.size() * num_interpolated_points);

  int diff = (song_data_size / song_data_increment) - (points.size() * num_interpolated_points);
  // Count up how many points we'll plot in this design so we can skip the correct number of song data points each subsequent point plot
  int total_points_to_plot = 0;
  for (int i = 0; i < points.length - 1; i++) {
    float x = points[i].x;
    float y = points[i].y;
    if (x == 0 || y == 0 || x == width || y == height) {
      continue;
    }
    
    float next_x = points[i + 1].x;
    float next_y = points[i + 1].y;
    float point_distance = distance_between_points(next_x, next_y, x, y);

    // Skip the larger distances we'll do jumps for in the draw loop
    if (point_distance <= 5) {
      total_points_to_plot += (int)Math.floor(point_distance / distance_between_points);
    }
  }
  
  println("Actual total plottable points after dynamic interpolation based on 'distance_between_points': " + total_points_to_plot);
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
  //to the start of the real data here lets us avoid an if-check every point increment in the loop below.
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
  if (points_index + 1 >= points.length || points_index < 0) {
    //if (points_index > 8000) {
    finishAndExit();
    return;
  };
  
  float x = points.get(points_index).x;
  float y = points.get(points_index).y;
  float next_x = points.get(points_index + 1).x;
  float next_y = points.get(points_index + 1).y;
  float point_distance = distance_between_points(next_x, next_y, x, y);

  //  "Raise the pen" and move to the next point if we're about to make a big jump,
  // meaning out next point isn't on the continuous line of the originally drawing. //<>//
  // Otherwise we get big lines all across the drawing. //<>//
  if (point_distance > 5) { //<>//
    vertex(x, y); //<>//
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
      int percent_drawn = (actual_vertices_drawn / (points.size() * num_interpolated_points)) * 100;
      int percent_drawn = (actual_vertices_drawn / (points.length * 2)) * 100;
      println("New file " + base_filename + (files_created) + ".pdf at total vertices drawn " + actual_vertices_drawn + "(" + percent_drawn + "%)");
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

  // An extra bounds check to make sure this set of interpolated points between two coords won't put us over our song data size.
  // Have to check instead of including in initial draw() bounds checks because we don't know num_interpolated_points until now
  int num_interpolated_points = (int)Math.floor(point_distance / distance_between_points);
  if (song_data_index + num_interpolated_points * song_data_increment > song_data_size) {
    finishAndExit();
    return;
  }
  
  // Interpolate the line between the two points given to us from the RShape to pack sound data tighter.
  // In theory this should be constant but there's a weird thing where every 5 to 10 (not sure) RShape points is
  // not spaced at the set polygonizerLength of 1.
  // TODO small perf improvement making num_interpolated_points power of 2 and shifting here
  float x_step_length = diff_x / num_interpolated_points;
  float y_step_length = diff_y / num_interpolated_points;
  for (int i = 0; i < num_interpolated_points; i++) {
    // Base point (x/y) + the interpolated distance straight on the line to the next point + 
    //the song data x/y normalized to the overall angle between RShape points    
    float adj_x = x + (i * x_step_length) + (song_data[song_data_index] * sin(angle));
    float adj_y = y - (i * y_step_length) + (song_data[song_data_index] * cos(angle));
    
    vertex(adj_x, adj_y);
    song_data_index += song_data_increment;
  }

  points_index++;
}

float[] process_audio_text_file(String input_filename) {
    // Load full comma-delimeted file - no line breaks so just grab the first index for everthing
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
