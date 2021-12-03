# Wav to Txt

#Original code by Amanda Ghassaei
#https://www.instructables.com/member/amandaghassaei/

# Adapted by Brian Team
# https://brian.team

## * This program is free software; you can redistribute it and/or modify
## * it under the terms of the GNU General Public License as published by
## * the Free Software Foundation; either version 3 of the License, or
## * (at your option) any later version.

# this code unpacks and repacks data from:
# 16 bit stereo wav file at 44100hz sampling rate
# and saves it as a txt file

import sys
import os
import wave
import math
import struct

if len(sys.argv) != 2:
    print("Must supply wav filename")
    sys.exit(1)

fileName = str(sys.argv[1])

if (not os.path.exists(fileName)) or (not os.path.isfile(fileName)):
    print("Invalid file, check the path")
    sys.exit(1)


bitDepth = 8#target bitDepth
frate = 44100#target frame rate

#read file and get data
w = wave.open(fileName, 'r')
numframes = w.getnframes()

frame = w.readframes(numframes)#w.getnframes()

frameInt = map(ord, list(frame))#turn into array

#separate left and right channels and merge bytes
frameOneChannel = [0]*numframes#initialize list of one channel of wave
print("Processing {} total frames, skipping 9 frames for every one processed for an end result of {} data points".format(numframes, numframes / 10))
for i in range(0, numframes, 10):
    frameOneChannel[i] = frameInt[4*i+1]*2**8+frameInt[4*i]#separate channels and store one channel in new list
    if frameOneChannel[i] > 2**15:
        frameOneChannel[i] = (frameOneChannel[i]-2**16)
    elif frameOneChannel[i] == 2**15:
        frameOneChannel[i] = 0
    else:
        frameOneChannel[i] = frameOneChannel[i]

#convert to string
audioStr = ''
for i in range(0, numframes, 10):
    audioStr += str(frameOneChannel[i])
    audioStr += ","#separate elements with comma

fileName = fileName[:-3]#remove .wav extension
text_file = open(fileName+"txt", "w")
text_file.write("%s"%audioStr)
text_file.close()
