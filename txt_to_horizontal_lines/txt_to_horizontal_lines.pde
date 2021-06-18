import processing.pdf.*;

public static final int SECS_PER_MIN = 60;
public static final int PX_PER_IN = 72;  // Scale factor of vectors, default 72 dpi (not sure about this one)
public static final float VERTICAL_BUFFER_IN = .2;
public static final float SIDE_BUFFER_IN = .2;

// Audio params
float sampling_rate_hz = 44100; // Sampling rate that wav file exported at

// Laser cutter params
float laser_cutter_dpi = 1200;  // DPI of laser cutter being used
int cutter_width_in = 36;
int cutter_height_in = 24;
float min_point_to_point_distance_pixels = 6.0;  // Minimum distance between vector points to prevent laser cutter from stalling
int num_rows_per_file = 200;  // Some laser cutters can't handle super large vector files, this splits into multiple sub-pdfs
int cut_width_in = 4; // Finished piece width 
int cut_height_in = 4; // Finished piece height
float distance_from_edge_in = 0.25;    // Distance from edge of bed to top and left side of square cut, inches

// Drawing params
float waveform_amplitude_pixels = 100; // Total amplitude of audio waveform to scale to
float horizontal_increment_pixels = 0.2;   // Number of pixels between each point side to side
int side_buffer_pixels = int(SIDE_BUFFER_IN * PX_PER_IN);        // Number of pixels on either side to leave between edge and beginning/end of waveform. Top/bottom spacing smaller
int vertical_buffer_pixels = int(VERTICAL_BUFFER_IN * PX_PER_IN);    // because it will be additionally offset by half of a line_spacing_pixel amount
boolean include_cutlines = true;


void setup() {
    String input_filename = "when_the_partys_over_hook.txt";

    // Scale distances in pixels to correct vector positioning
    waveform_amplitude_pixels = waveform_amplitude_pixels / laser_cutter_dpi * PX_PER_IN;
    min_point_to_point_distance_pixels = min_point_to_point_distance_pixels / laser_cutter_dpi * PX_PER_IN;

    // Intake csv text, tranform to floats and normalize based on max value and waveform amplitude setting
    float[] song_data = process_audio_text_file(input_filename);

    // Build output filename
    String output_filename = input_filename;
    int period_pos = output_filename.lastIndexOf(".");
    if (period_pos > 0) {
        output_filename = output_filename.substring(0, period_pos);
    }

    // Construct output pdf file
    // Must be constant: cutter_width_in * DPI_SCALE, cutter_height_in * DPI_SCALE
    size(2592, 1728);
    beginRecord(PDF, output_filename + "0.pdf");
    background(255);
    noFill();
    strokeWeight(0.001);

    stroke(255, 0, 0);

    // Point of refernce for all measurements
    float x_origin_pixels = distance_from_edge_in * PX_PER_IN;
    float y_origin_pixels = distance_from_edge_in * PX_PER_IN;
    int cut_width_pixels = cut_width_in * PX_PER_IN;
    int cut_height_pixels = cut_height_in * PX_PER_IN;
    
     // Number of horizontal points per waveform row. Scales based on horizontal increment size
    int horizontal_iterations_per_row = int((cut_width_pixels - 2 * side_buffer_pixels) / horizontal_increment_pixels); 
  
    // Number of entries to move in the data array each time we go to draw another point
     int data_increment = 10; //int((sampling_rate_hz * SECS_PER_MIN) / 45 / horizontal_iterations_per_row);
    
    // Spread rows evenly across full height available. line_spacing_pixels is a float to preserve accumulation of decimals in
    // y offset at it's continuosly added to it(see comment above current_draw_y_offset for more info)
    int rows = (int)Math.ceil((float)song_data.length / data_increment / horizontal_iterations_per_row);
    float line_spacing_pixels = (float)(cut_height_pixels - 2 * vertical_buffer_pixels) / rows;
    
    // Use floats because we want to retain the decimal amount when incrementing line_spacing_pixels each row.
    // If we don't, the more rows we have, the more the bottom row will be further away from the bottom than the
    // top row is from the top (on the order of ~8 pixels for 24 rows)
    float current_draw_x_offset = side_buffer_pixels + x_origin_pixels;
    float current_draw_y_offset = y_origin_pixels + vertical_buffer_pixels + line_spacing_pixels / 2;
    
    int data_index = 0;    // Overall data index as we walk along the data. This is our condition for breaking out of the while loop
    int index_to_use = data_index; // What we actually use to index, so we can loop back to beginning of song to finish out row
    float x_pos = 0;
    float y_pos = 0;
    float previous_x_pos = 0;
    float previous_y_pos = 0;
    float distance_squared;
    
    while (data_index < song_data.length) {      
        // Start a new line
        beginShape();
        
        // for loop iterating through full row of X offsets
        for (int i = 0; i < horizontal_iterations_per_row; i++) {
          // Calc X always even if we're done with song data
          x_pos = current_draw_x_offset + i * horizontal_increment_pixels;
          
          // Check out index each iteration to make sure we don't overflow since we increment in here but the outer while loop has the guard
          if (data_index >= song_data.length) {
            // Finish the row by looping back to beginning of song data so we don't have an ugly flat line or nothing at all
            //vertex(x_pos, current_draw_y_offset);
            //continue;
            index_to_use = data_index - song_data.length;
          } else {
            index_to_use = data_index;
          }
          
          // We still have data, plot a real point
          y_pos = current_draw_y_offset + song_data[index_to_use];

          // Only draw this point if it's greater than our min supported distance
          distance_squared = distance_between_points_squared(x_pos, y_pos, previous_x_pos, previous_y_pos);
          if (distance_squared >= (min_point_to_point_distance_pixels * min_point_to_point_distance_pixels)) {
              vertex(x_pos, y_pos);
              previous_x_pos = x_pos;
              previous_y_pos = y_pos;
          }

          data_index += data_increment;
        }

        // Stop drawing to reset cursor to beginning of next row w/o connecting with a line
        endShape();
        current_draw_y_offset += line_spacing_pixels;
    }
    
    if (include_cutlines) {
        stroke(0);
        noFill();
        beginShape();
        vertex(x_origin_pixels, y_origin_pixels);
        vertex(x_origin_pixels + cut_width_pixels, y_origin_pixels);
        vertex(x_origin_pixels + cut_width_pixels, y_origin_pixels + cut_height_pixels);
        vertex(x_origin_pixels, y_origin_pixels + cut_height_pixels);
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
