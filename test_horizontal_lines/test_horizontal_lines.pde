import processing.pdf.*;
import processing.svg.*;

static int PX_PER_IN = 72;                  // Scale factor of vectors, default 72 dpi (not sure about this one)
static int width_in = 72;
static int height_in = 48;
static float mill_tip_diameter_in = 0.19685;
static int side_buffer_in = 2;
static int vertical_buffer_in = 2;
static int num_lines = 20;

static int width_px = width_in * PX_PER_IN;
static int height_px = height_in * PX_PER_IN;
static float mill_tip_diameter_px = mill_tip_diameter_in * PX_PER_IN;
static int side_buffer_px = side_buffer_in * PX_PER_IN;
static int vertical_buffer_px = vertical_buffer_in * PX_PER_IN;

void setup() {
  size(5184, 3456);
  beginRecord(SVG, "test_horizontal_lines.svg");
  background(255);
  beginShape();
  stroke(0);
  stroke(mill_tip_diameter_px);
  noFill();

  float line_spacing = (height_px - 2 * vertical_buffer_px) / (float)num_lines;
  int x_0 = side_buffer_px;
  float y = vertical_buffer_px;
  int x_1 = width_px - side_buffer_px;

  for (int i = 0; i <= num_lines; i++) { 
    line(x_0, y, x_1, y);
    y += line_spacing;
  }

  //}
  //line(side_buffer_px + end_cap_length_px, height_px - side_buffer_px, side_buffer_px, height_px - side_buffer_px - end_cap_length_px);
  //line(side_buffer_px, height_px - side_buffer_px - end_cap_length_px, side_buffer_px, height_px - side_buffer_px - end_cap_length_px * 2);
  //line(side_buffer_px, height_px - side_buffer_px - end_cap_length_px * 2, side_buffer_px + end_cap_length_px * 2, height_px - side_buffer_px);
  //line(side_buffer_px + end_cap_length_px * 2, height_px - side_buffer_px, side_buffer_px + end_cap_length_px * 3,  height_px - side_buffer_px);
  //line(side_buffer_px + end_cap_length_px * 3,  height_px - side_buffer_px, side_buffer_px, height_px - side_buffer_px - end_cap_length_px * 3);

  endRecord();
  noLoop();
  stop();
  exit();
}

void draw() {
}
