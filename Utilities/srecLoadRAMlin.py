#!/usr/bin/python3

# this is a quick and dirty script to read an SRecord format file 
# (or any ASCII file, really) and output it via a specified serial port
# with a brief per-line delay to allow the target machine some time
# to process the line it just recieved. 
# there is no real error checking here, just read & output

import time
import sys
import serial

if len(sys.argv) < 3:
    print("Usage: srecLoadRAMlin.py <tty> <program>")
    exit()

# open the specified serial port
try:
    ser = serial.Serial(port=sys.argv[1],baudrate=37400,timeout=1)
    ser.flushInput()
    ser.flushOutput()
except Exception as e:
    print("Error opening serial port: " + str(e))
    ser.close()
    exit()

# open the specified file
try:
    f = open(sys.argv[2],'r',encoding='ascii')
except Exception as e:
    print("Error opening file: " + str(e))
    exit()

# send the file over the serial port
for line in f.readlines():
    ser.write(bytes(line.rstrip('\n')+'\r\n','ascii'))
    print(line)
    time.sleep(0.001)
