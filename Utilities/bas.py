#!/usr/bin/python
import time
import sys
import serial

if len(sys.argv) < 3:
    print("Usage: bas.py <tty> <program>")
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

try:
    f = open(sys.argv[2],'r',encoding='ascii')
except Exception as e:
    print("Error opening file: " + str(e))
    exit()

# send a break in case BASIC is currently running a program
ser.write(bytes('\x03','ascii'))
time.sleep(1)

# tell BASIC to start a new program
ser.write(bytes('NEW\r\n','ascii'))
time.sleep(1)

for line in f.readlines():
    ser.write(bytes(line.rstrip('\n')+'\r\n','ascii'))
    print(line)
    # delay after each line to allow BASIC to process it
    time.sleep(0.012*len(line))