import geomerative.*;
import processing.pdf.*;

// https://discourse.processing.org/t/calculate-distance-from-point-to-closest-point-of-shape/7201/7

static int width = 500;
static int height = 600;
static int song_data_size = 13000;
static int num_interpolated_points = 10;    // Number of points we stick in between each point on svg line given to us by RG getPoints (smallest point space between those points still too big)

RShape myshape;
RPoint [] points;

float song_data[] = new float[song_data_size];
int points_index = 0;                      // Start with second point to pre-calc the diffs'
int song_data_index = points_index;
int x_sign;
int y_sign;

void setup () {
  assert(width == 500);
  assert(height == 600);
  size (500, 600);  //<>//
  
  RG.init(this);
  myshape = RG.loadShape ("mountains.svg");
  RG.setPolygonizerLength(1);
  points = myshape.getPoints();
  points = (RPoint[])subset(points, 2000);
  println("Processing " + points.length + " points");
  
  boolean flip = true;
  for (int i = 0; i < song_data_size; i++, flip = !flip) {
    song_data[i] = flip ? -0.5 : 0.5;
  }
  
  beginRecord(PDF, "line_following.pdf");
  background(255);
  beginShape();
  stroke(0);
  strokeWeight(0.01);
  noFill();
  
  // hack to skip our first point so our diff calc works right now
  points_index++;
}

void draw() {
  if (points_index + 1 >= points.length || (song_data_index + num_interpolated_points) >= song_data.length || points_index < 0) {
    println("Bailing at points_index of " + points_index);
    endShape();
    endRecord();
    exit();
    return;
  };
  
  // Assumption that we're not at the first point since we bailed for border points
  float x = points[points_index].x;
  float y = points[points_index].y;
  float next_x = points[points_index + 1].x;
  float next_y = points[points_index + 1].y;
  float point_distance = distance_between_points(x, y, points[points_index - 1].x, points[points_index - 1].y);
  
  // Chunk up vectors, processing can only do so many points in one shape.
  // Also "raise the pen" if we're about to make a big jump, meaning out next point
  // isn't on the continuous line of the originally drawing. Otherwise we get big
  // lines all across the drawing.
  boolean long_jump = point_distance > 5;
  if (long_jump || (song_data_index % 500 == 0 && song_data_index != 0)) {
    println("Switching to new shape at " + points_index);
    endShape();
    beginShape();
    
    // TODO don't leave a one segment gap
    //vertex(prev_x, prev_y);
  }
  
  //Don't do the border
  if (x != 0 && y != 0 && x != width && y != height) {
    float diff_x = next_x - x;
    float diff_y = -1 * (next_y - y);
    float angle = atan2(diff_y, diff_x);
    //angle += PI;
    float sin = sin(angle);
    float cos = cos(angle);

    // Interpolate the line between the two points given to us from the RShape to pack sound data tighter
    float x_step_length = diff_x / num_interpolated_points;
    float y_step_length = diff_y / num_interpolated_points;
    for (int i = 0; i < num_interpolated_points; i++) {
      // Base point (x/y) + the interpolated distance straight on the line to the next point + 
      //the song data x/y normalized to the overall angle between RShape points    
      float adj_x = x + (i * x_step_length) + (song_data[song_data_index] * sin);
      float adj_y = y - (i * y_step_length) + (song_data[song_data_index] * cos);
      
      vertex(adj_x, adj_y);

      song_data_index++;
    }
  }

  points_index++;  
  //song_data_index++;
}

// Rough - rounds off the decimal. Only used for large point jumps to keep from drawing lines across whole image
float distance_between_points(float x, float y, float prev_x, float prev_y) {
  return sqrt((x - prev_x) * (x - prev_x) + (y - prev_y) * (y - prev_y));
}
