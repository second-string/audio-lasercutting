import processing.svg.*;
import processing.pdf.*;

public static final int PX_PER_IN = 72;  // Scale factor of vectors, default 72 dpi (not sure about this one)

// ---------- PER-SONG PARAMS ----------
// You will need to change or tweak these for every new song cut you're doing

String input_filename = "dark_star_live_at_fillmore_east.txt";
float waveform_amplitude_pixels = 6; // Total amplitude of audio waveform to scale to
float distance_between_points_pixels = 0.3;   // Number of pixels between each vertex plotted
int data_increment = 22;      // Number of entries to move in the data array each time we go to draw another point
boolean include_cutlines = true;
boolean split_into_smaller_files = true;    // Set to true to create lots of multiple files w/ 4 spirals each instead of one monster. Useful for illustrator or some laser cutters that barf on files w/ ton of vertices in it

// ---------- END PER-SONG PARAMS

// ---------- Laser cutter params ----------
// Only change thsee to adapt code to new laser cutter. Should stay constant after that
int cutter_width_in = 36;
int cutter_height_in = 24;
float min_point_to_point_distance_pixels = 0.3;  // Minimum distance between vector points to prevent laser cutter from stalling
int spirals_in_file = 20;      // If split_into_smaller_files is true, this will draw this many spiral rotations in each pdf/svg file. Smaller number means quicker cuts on a laser cutter if you need to stop partway through the full spiral
// ---------- End Laser cutter params ----------

// ---------- Drawing params ----------
int cut_side_length_in = 12;       // Finished piece width / height
float distance_from_edge_in = 0.0;    // Distance from edge of bed to top and left side of square cut, inches
int side_buffer_pixels = 50;        // Number of pixels on either side to leave between edge and beginning/end of waveform
int vertical_buffer_pixels = 50;
float spiral_spacing_pixels = 20;    // TODO :: calculate spiral_spacing_pixels to dynamically size spiral based on nubmer of points to plot so it always starts at the origin and ends at a specific radius from center
// ---------- End Drawing params ----------




void setup() {
    // Intake csv text, tranform to floats and normalize based on max value and waveform amplitude setting
    float[] song_data = process_audio_text_file(input_filename); //<>//

    // Build output filename
    String output_filename = input_filename;
    int period_pos = output_filename.lastIndexOf(".");
    if (period_pos > 0) {
        output_filename = output_filename.substring(0, period_pos);
    }

    // Construct output pdf file
    // Must be constant: cutter_width_in * PX_PER_IN, cutter_height_in * PX_PER_IN
    // Changed to 12x12in, no need to make whole thing size of cutter bed
    size(864, 864);

    // Point of refernce for all measurements
    float x_origin_pixels = distance_from_edge_in * PX_PER_IN;
    float y_origin_pixels = distance_from_edge_in * PX_PER_IN;
    int cut_side_length_pixels = cut_side_length_in * PX_PER_IN;
    
     // Number of points on one side of the current spiral. Will need to decrement after 3 sides drawn to spiral inward. Scales based on horizontal increment size
    int iterations_per_side = int((cut_side_length_pixels - 2 * side_buffer_pixels) / distance_between_points_pixels); 
    
    // Spread rows evenly across full height available. line_spacing_pixels is a float to preserve accumulation of decimals in
    // y offset at it's continuosly added to it(see comment above current_draw_y_offset for more info)
    //int rows = (int)Math.ceil((float)song_data.length / data_increment / horizontal_iterations_per_row);
    //float line_spacing_pixels = (float)(cut_height_pixels - 2 * vertical_buffer_pixels) / rows;
    
    // Use floats because we want to retain the decimal amount when shortening line_spacing_pixels each finished spiral.
    // If we don't, the more spirals we have, the more the inner spiral will be further away from the center than the
    // outer spiral is from the outer cut edge
    float current_draw_x_offset = x_origin_pixels + side_buffer_pixels;
    float current_draw_y_offset = y_origin_pixels + vertical_buffer_pixels;
    
    int data_index = 0;    // Overall data index as we walk along the data. This is our condition for breaking out of the while loop
    int index_to_use = data_index; // What we actually use to index, so we can loop back to beginning of song to finish out row
    float x_pos = 0;
    float y_pos = 0;
    float previous_x_pos = 0;
    float previous_y_pos = 0;
    float distance_squared;
    
    // How many sides have we drawn so far in the spiral? Once == 3, decrease iterations_per_side by sprial_spacing_pixels
    int spiral_side_being_drawn = 0;
    int spiral_count = 0;
    
    int song_data_length = song_data.length;
    while (data_index < song_data_length) {
        // Illustrator only supports 32k points in a single vector, so chop it up every spiral
        // https://community.adobe.com/t5/illustrator/maximum-anchor-points-on-a-path/m-p/10163260
        if (spiral_side_being_drawn == 0) {
          // create a new fileif this is either our very first loop iteration OR if split files flag set and we've completed spirals_in_file rounds
          boolean createNewFile = (spiral_count == 0) || (split_into_smaller_files && spiral_count % spirals_in_file == 0);
          if (spiral_count > 0) {
            endShape();
            if (createNewFile) {
              endRecord();
            }
          }

          if (createNewFile) {
            // Put # in front of filename because lasercutter screen will cut off the end
            beginRecord(PDF, spiral_count / spirals_in_file + "_" + output_filename +  ".pdf");
            // Background call must be here to paint a full width by height background - otherwise you'd need to manually
            // offset each successively smaller squre in the cutter settings
            background(255);
            noFill();
            strokeWeight(0.3);
            stroke(255, 0, 0);
          }
          beginShape();
          
          if (spiral_count != 0) {
            vertex(previous_x_pos, previous_y_pos);
          }
        }
        
        if (iterations_per_side < 0) {
          // Should be unnecessary once/if we calculate distance between lines based on song data length
          println("iterations_per_side has gone negative, exiting before printing all song data");
          println("Made it " + ((float)(index_to_use * 100) / song_data_length) + "% through song data");
          break;
        }
      
        // Set our new x and y starting offsets after drawing a side to be at the end of that side, so we begin our next one from there
        switch (spiral_side_being_drawn) {
          case 0:
            if (spiral_count > 0) {
              // Move y offset from bottom left to (new) top left (skip our very first iteration since we already set this)
              // iterations_per_side has already been decremented appropriate amount to stay inside spiral
              current_draw_y_offset -= distance_between_points_pixels * iterations_per_side;
            }
            break;
          case 1:
            // Move x offset from top left to top right
            current_draw_x_offset += distance_between_points_pixels * iterations_per_side;
            
            if (spiral_count > 0) {
              iterations_per_side -= spiral_spacing_pixels; 
            }
            break;
          case 2:
            // Move y offset from top right to bottom right
            current_draw_y_offset += distance_between_points_pixels * iterations_per_side;
            break;
          case 3:
            // Move x offset from bottom right to bottom left
            current_draw_x_offset -= distance_between_points_pixels * iterations_per_side;
             
            // Decrement for this side to stay inside spiral
            iterations_per_side -= spiral_spacing_pixels;
            spiral_count++;
            break;
          default:
          // TODO :: throw
            break;
        }
        
        // for loop iterating through one full side of spiral
        for (int i = 0; i < iterations_per_side; i++) {
          // Check out index each iteration to make sure we don't overflow since we increment in here but the outer while loop has the guard
          if (data_index >= song_data.length) {
            // Finish the row by looping back to beginning of song data so we don't have an ugly flat line or nothing at all
            //vertex(x_pos, current_draw_y_offset);
            //continue;
            index_to_use = data_index - song_data.length;
          } else {
            index_to_use = data_index;
          } 
          
          switch (spiral_side_being_drawn) {
            case 0:
              // Top
              x_pos = current_draw_x_offset + i * distance_between_points_pixels;
              y_pos = current_draw_y_offset + song_data[index_to_use];
              break;
            case 1:
              // Right
              x_pos = current_draw_x_offset + song_data[index_to_use];
              y_pos = current_draw_y_offset + i * distance_between_points_pixels;
              break;
            case 2:
              // Bottom (reverse y values, move x backwards)
              x_pos = current_draw_x_offset - i * distance_between_points_pixels;
              y_pos = current_draw_y_offset - song_data[index_to_use];
              break;
            case 3:
              // Left (reverse x values, move y backwards)
              x_pos = current_draw_x_offset - song_data[index_to_use];
              y_pos = current_draw_y_offset - i * distance_between_points_pixels;
              break;
            default:
              // TODO :: throw
              break;
          }


          // Only draw this point if it's greater than our min supported distance
          distance_squared = distance_between_points_squared(x_pos, y_pos, previous_x_pos, previous_y_pos);
          //if (distance_squared >= (min_point_to_point_distance_pixels * min_point_to_point_distance_pixels)) {
              vertex(x_pos, y_pos);
              previous_x_pos = x_pos;
              previous_y_pos = y_pos;
          //}

          data_index += data_increment;
        }

        // Stop drawing to reset cursor to beginning of next row w/o connecting with a line
        //endShape();
          
        if (spiral_side_being_drawn >= 3) {
          // Reset for new top-left inner spiral
          spiral_side_being_drawn = 0;
        } else {
          spiral_side_being_drawn++;
        }
    }
    
    endShape();
    
    if (include_cutlines) {
        stroke(0.5);
        stroke(0, 0, 0);
        noFill();
        beginShape();
        vertex(x_origin_pixels, y_origin_pixels);
        vertex(x_origin_pixels + cut_side_length_pixels, y_origin_pixels);
        vertex(x_origin_pixels + cut_side_length_pixels, y_origin_pixels + cut_side_length_pixels);
        vertex(x_origin_pixels, y_origin_pixels + cut_side_length_pixels);
        endShape(CLOSE);
    }

    // Finish out file and close window
    endRecord();
    exit();

    println("Finished");
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

float distance_between_points_squared(float x_0, float y_0, float x_1, float y_1) {
    return (x_1 - x_0) * (x_1 - x_0) + (y_1 - y_0) * (y_1 - y_0);
}
