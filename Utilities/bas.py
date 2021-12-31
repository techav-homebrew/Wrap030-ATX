#!/usr/bin/python
import time
import sys
import serial

if len(sys.argv) < 3:
    print("Usage: bas.py <tty> <program>")
    exit()

# open the specified serial port
ser = serial.Serial(port=sys.argv[1],baudrate=37400,timeout=1)
try:
    ser.open()
    ser.flushInput()
    ser.flushOutput()
except Exception as e:
    print("Error opening serial port: " + str(e))
    ser.close()
    exit()

try:
    f = open(sys.argv[2],'r',encoding='ascii')
except Exception as e:
    print("Error opening file: " + str(e))
    exit()

for line in f.readlines():
    ser.write(lin)
    print(lin)
    # delay after each line to allow BASIC to process it
    time.sleep(0.5)