import geomerative.*;
import processing.pdf.*;

// https://discourse.processing.org/t/calculate-distance-from-point-to-closest-point-of-shape/7201/7

static int PX_PER_IN = 72;                  // Scale factor of vectors, default 72 dpi (not sure about this one)
static int width_in = 12;
static int height_in = 12;

static int num_interpolated_points = 9;    // Number of points we stick in between each point on svg line given to us by RG getPoints (smallest point space between those points still too big)

// Drawing params
static float waveform_amplitude_pixels = 1.8; // Total amplitude of audio waveform to scale to
static int song_data_increment = 14;        // Number of indexes to skip ahead for each song_data point we pull (full array can be in tens of millions)
//static float min_point_to_point_distance_pixels = 0.1;  // Minimum distance between vector points to prevent laser cutter from stalling
//static float laser_cutter_dpi = 1200;        // DPI of laser cutter being used
String base_filename;
boolean split_pdfs = false;
int files_created = 0;

float song_data[] = new float[] {};
int song_data_size;
RPoint [] points;

//float song_data[] = new float[song_data_size];
int points_index = 0;                      // Start with second point to pre-calc the diffs'
int song_data_index = points_index;
int x_sign;
int y_sign;

void setup () {
  // Have to do this bs because you can't pass non-constants to size()
  // Normally we would calc width_px/height_px by multiplying width_in * PX_PER_IN
  // If you change the values in the asserts, recalculate the values in size() manually
  assert(width_in == 12);
  assert(height_in == 12);
  size(864, 864); 
  
  String song_data_filename = "time_you_and_i.txt";
  String shape_filename = "rainier.svg";
  
  // Pull in song data in txt form and normalize it
  // Intake csv text, tranform to floats and normalize based on max value and waveform amplitude setting
  song_data = process_audio_text_file(song_data_filename);
  song_data_size = song_data.length;
  println("Total points received from song data: " + song_data_size);
  println("Song data increment size: " + song_data_increment);
  println("Total song data points to be used: " + song_data_size / song_data_increment);
  
  // Pull in points from base image .svg
  RG.init(this);
  RShape svg_shape = RG.loadShape (shape_filename);
  
  // Scales the svg to the correct width/height, 12in x 12in.
  // This assumes that the input .svg is square already. If not, it
  // will scale the longest edge to 12in but still retain aspect ratio
  float shape_height = svg_shape.getHeight();
  float shape_width = svg_shape.getWidth();
  float max_side_length = shape_height > shape_width ? shape_height : shape_width;
  
  // width_in * PX_PER_IN is scaling to same value we passed into size(x,y) at the beginning of setup()
  svg_shape.scale((width_in * PX_PER_IN) / max_side_length);
  
  RG.setPolygonizerLength(1);
  points = svg_shape.getPoints();
  println("Total points from RShape:  " + points.length);
  println("Total points to print shape after interpolation: " + points.length * num_interpolated_points);
  println("Total number of song data entries after increment scaling: " + song_data_size / song_data_increment);

  int diff = (song_data_size / song_data_increment) - (points.length * num_interpolated_points);
  if (diff > 0) {
    float percent = (float)(abs(diff)) / (song_data_size / song_data_increment);
    println("Able to plot " + (1 - percent) * 100 + "% of song data points.");
    println("Consider increasing num_interpolated_points or song_data_increment or skipping more frames in wav_to_txt.py");
  } else {
    float percent = (float)(abs(diff)) / (points.length * num_interpolated_points);
    println("Song data only fills up " + (1 - percent) * 100 + "% of plottable points.");
    println("Consider decreasing num_interpolated_points or song_data_increment or skipping less frames in wav_to_txt.py");
    exit();
    return;
  }
  
  if (diff > 20000) {
    println("Gap between shape points and song data greater than 20,000, exiting. Adjust parameters and try again");
    exit();
    return;
  }
  
  base_filename = song_data_filename.substring(0, song_data_filename.lastIndexOf('.')) + "_" + shape_filename.substring(0, shape_filename.lastIndexOf('.')) + "_line_following_";
  beginRecord(PDF, base_filename + (files_created++) + ".pdf");
  background(255);
  beginShape();
  stroke(0);
  strokeWeight(0.4);
  noFill();
  
  // Assume border (if there is one) is all in front of array. Pre-incrementing our points_index
  //to the start of the real data here lets us avoid an if-check every point increment in the loop below.
  // If no border, we lose the first point (meh)
  float x;
  float y;
  do {
    x = points[points_index].x;
    y = points[points_index].y;
    points_index++;    
  } while (x == 0 || y == 0 || x == width || y == height);
}

void draw() {
  if (points_index + 1 >= points.length || (song_data_index + num_interpolated_points * song_data_increment) >= song_data_size || points_index < 0) {
    println("Bailing at points_index of " + points_index);
    endShape();
    endRecord();
    exit();
    return;
  };
  
  float x = points[points_index].x;
  float y = points[points_index].y;
  float next_x = points[points_index + 1].x;
  float next_y = points[points_index + 1].y;
  float point_distance = distance_between_points(next_x, next_y, x, y);

  //  "Raise the pen" and move to the next point if we're about to make a big jump,
  // meaning out next point isn't on the continuous line of the originally drawing.
  // Otherwise we get big lines all across the drawing.
  if (point_distance > 5) {
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
      int percent_drawn = (actual_vertices_drawn / (points.length * num_interpolated_points)) * 100;
      println("New file " + base_filename + (files_created) + ".pdf at total vertices drawn " + actual_vertices_drawn + "(" + percent_drawn + "%)");
      endRecord();
      beginRecord(PDF, base_filename + (files_created++) + ".pdf");
      background(255);
      beginShape();
      stroke(0);
      strokeWeight(0.1);
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
