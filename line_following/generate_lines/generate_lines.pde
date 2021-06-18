import processing.svg.*;

void setup() {
  beginRecord(SVG, "line_following_test_lines.svg");
  size (500,600); 
  background(255);
  noFill();
  strokeWeight(1);
  stroke(0);
  
  //draw_line(100, 100, 400, 100);
  //draw_jagged();
  beginShape();
  ellipse(250, 250, 400, 400);
  endShape();
  
  endRecord();
  exit();
}

void draw_jagged() {
  beginShape();
  vertex(100, 425);
  vertex(150, 375);
  vertex(200, 425);
  vertex(250, 375);
  vertex(300, 425);
  vertex(350, 375);
  vertex(400, 425);
  endShape();
}

void draw_line(float x_start, float y_start, float x_end, float y_end) {
  beginShape();
  vertex(x_start, y_start);
  vertex(x_end, y_end);
  endShape();
}
