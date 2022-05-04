  //record vector cutting file generator 
  //by Amanda Ghassaei
  //May 2013
  //http://www.instructables.com/id/Laser-Cut-Record/
  //detailed instructions for using this code at http://www.instructables.com/id/Laser-Cut-Record/step7

  /*
   * This program is free software; you can redistribute it and/or modify
   * it under the terms of the GNU General Public License as published by
   * the Free Software Foundation; either version 3 of the License, or
   * (at your option) any later version.
  */

  import processing.pdf.*;

  //parameters
  String filename = "innerbloom.txt";//generate a txt file of your waveform using python wav to txt, and copy the file name here
  float rpm = 45.0;//33.3,45,78
  float samplingRate = 48000;//sampling rate of incoming audio
  float dpi = 240;//dpi of cutter
  int cutterWidth = 12;//width of laser cutter bed in inches
  int cutterHeight = 12;//height of laser cutter bed in inches
  float amplitude = 30;//in pixels
  float spacing = 45;//space between grooves (in pixels)
  float minDist = 0.1;//min pixel spacing between points in vector path (to prevent cutter from stalling)
  float thetaIter = 3280;//how many values of theta per cycle
  float diameter = 11;//diameter of record in inches
  float innerHole = 0.1;//diameter of center hole in inches
  float innerRad = 0.25;//radius of innermost groove in inches
  float outerRad = 5.5;//radius of outermost groove in inches
  boolean cutlines = false;//cut the inner and outer perimeters
  boolean drawBoundingBox = true;//draw a rect around the whole thing (helps with alignment)
  int numGroovesPerFile = 2;//many lasers will choke if you send them all the data at once, this number spits the cutting path into several files taht can be sent to the laser cutter in series, decrease this number to lower the amount of data on each section



  void setup(){

    //constants
    float secPerMin = 60;
    int scaleNum = 72;//scale factor of vectors (default 72 dpi)

    //storage variables
    float radCalc;
    float xVal;
    float yVal;
    float theta;//angular variable
    float radius;
    float xValLast = 0.0;
    float yValLast = 0.0;

    //scale pixel distances
    amplitude =  amplitude/dpi*scaleNum;
    minDist =  minDist/dpi*scaleNum;
    spacing =  spacing/dpi*scaleNum;

    float[] songData = processAudioData();

    //change extension of file name
    int dotPos = filename.lastIndexOf(".");
    if (dotPos > 0)
      filename = filename.substring(0, dotPos);

    //open pdf file
    //size(cutterWidth*scaleNum,cutterHeight*scaleNum);
    size(864,864);
    int section = 1;
    beginRecord(PDF, filename + "0.pdf");//save as PDF
    background(255);//white background
    noFill();//don't fill loops
    strokeWeight(0.4);//hairline width

    //init variables
    float incrNum = TWO_PI/thetaIter;//calculcate angular inrementation amount
    float radIncrNum = (spacing)/thetaIter;//radial incrementation amount
    radius = outerRad*scaleNum;//calculate outermost radius (at 5.75")

    stroke(255,0,0);//red
    beginShape();//start vecotr path

    int numGrooves = 1;
    int index = 0;
    int indexIncr = 49;
    while(radius>innerRad*scaleNum && index < songData.length-thetaIter*indexIncr){
      for(theta=0;theta<TWO_PI;theta+=incrNum){//for theta between 0 and 2pi
        //calculate new point
        radCalc = radius+songData[index];
        index+=indexIncr;//go to next spot in audio data
        xVal = 6*scaleNum+radCalc*cos(theta);
        yVal = 6*scaleNum-radCalc*sin(theta);
        if(((xValLast-xVal)*(xValLast-xVal)+(yValLast-yVal)*(yValLast-yVal))>(minDist*minDist)){
          vertex(xVal,yVal);
          //store last coordinates in vector path
          xValLast = xVal;
          yValLast = yVal;
        }
        radius -= radIncrNum;//decreasing radius forms spiral
      }
      numGrooves++;
      if (numGrooves%numGroovesPerFile==0){
        endShape();
        beginShape();
        vertex(xValLast,yValLast);
      }
      println(numGrooves);
      thetaIter -= 105;
      incrNum = TWO_PI/thetaIter;
      radIncrNum = (spacing)/thetaIter;
    }

    ////draw silent inner locked groove
    for(theta=0;theta<TWO_PI;theta+=incrNum){//for theta between 0 and 2pi
      //calculate new point
      radCalc = radius;
      xVal = 6*scaleNum+radCalc*cos(theta);
      yVal = 6*scaleNum-radCalc*sin(theta);
      if(((xValLast-xVal)*(xValLast-xVal)+(yValLast-yVal)*(yValLast-yVal))>(minDist*minDist)){
        vertex(xVal,yVal);
        //store last coordinates in vector path
        xValLast = xVal;
        yValLast = yVal;
      }
      radius -= radIncrNum;//decreasing radius forms spiral
    }
    endShape();

    if (cutlines){
      //draw cut lines (100 units = 1")
      stroke(0);//draw in black
      ellipse(6*scaleNum,6*scaleNum,innerHole*scaleNum,innerHole*scaleNum);//0.286" center hole
      ellipse(6*scaleNum,6*scaleNum,diameter*scaleNum,diameter*scaleNum);//12" diameter outer edge 
    }

    endRecord();
    exit();

    println("Made it through " + index * 100 / songData.length + "% of song data"); 
    //tell me when it's over
    println("Finished.");

  }

  float[] processAudioData(){

    //get data out of txt file
    String rawData[] = loadStrings(filename);
    String rawDataString = rawData[0];
    float audioData[] = float(split(rawDataString,','));//separated by commas

    //normalize audio data to given bitdepth
    //first find max val
    float maxval = 0;
    for(int i=0;i<audioData.length;i++){
      if (abs(audioData[i])>maxval){
        maxval = abs(audioData[i]);
      }
    }
    //normalize amplitude to max val
    for(int i=0;i<audioData.length;i++){
      audioData[i]*=amplitude/maxval;
    }

    return audioData;
  }
