#!/usr/bin/python
import time
import sys
import serial
 
ser = serial.Serial(port='COM5', baudrate=115200, timeout=1)

if ser.isOpen():
	ser.close()

try:
	ser.open()
except Exception as e:
	print("Error opening serial port: " + str(e))
	exit()

time.sleep(1)

if ser.isOpen():
	try:
		#ser.flushInput()
		#ser.flushOutput()
		ser.write(b'?\r\n')
		time.sleep(0.5)
		ser.flushInput()
		ser.flushOutput()
	except Exception as e:
		print("Error initializing serial port: " + str(e))
		ser.close()
		exit()
		
try:
	f = open(sys.argv[1], 'r', encoding='ascii')
except Exception as e:
	print("Error opening file: " + str(e))
	exit()

time.sleep(1)

checkErase = 1
if len(sys.argv) > 2:
    if sys.argv[2]==0 or sys.argv[2]=="false" or sys.argv[2]=="0":
        checkErase = 0

needsErase = 0
if checkErase == 0:
    print("Skiping chip erase check.")
else:
    print("Checking if chip needs erasing...")
    for x in range(1,8):
        ser.read_until(expected=b'>')
        ser.write(b'VERIFY\r\n')
        ser.read_until(expected=b':')
        sectStr = str(x) + "\r\n"
        ser.write(bytes(sectStr,'ascii'))
        ser.read_until(expected=b'\n')
        time.sleep(2.0)
        sectStatus = ser.read_until(expected=b'>')
        #print(sectStatus)
        if "Sector has data" in sectStatus.decode("utf-8"):
            print("Sector " + str(x) + " has data.")
            needsErase = 1
            break
        elif "Sector is erased" in sectStatus.decode("utf-8"):
            print("Sector " + str(x) + " is clear.")
            continue
        elif "Sector is Locked" in sectStatus.decode("utf-8"):
            print("Sector " + str(x) + " is locked. Erase may fail.")
            needsErase = 1
            break
        else:
            print("Unknown sector " + str(x) + " status: " + sectStatus.decode("utf-8"))
            continue

if needsErase == 1 and checkErase == 1:
    print("Attempting to erase chip...")
    ser.read_until(expected=b'>')
    ser.write(b'ERASE\r\n')
    ser.read_until(expected=b'?')
    ser.write(b'CHIP\r\n')
    ser.read_until(expected=b':')
    ser.write(b'YES\r\n')
    #ser.read_until(expected=b'>')
    while 1:
        rDat = ser.read(1)
        print(rDat.decode('utf-8'),end='')
        if rDat == b'>':
            break

print("Write start...")
#ser.read_until(expected=b'>')
ser.write(b'write\r\n')
#time.sleep(0.5)
ser.read_until(expected=b'?')
ser.write(b'all\r\n')
time.sleep(0.5)
#ser.flushInput()

for line in f.readlines():
    txErr = 0
    while 1:
        rDat = ser.read(1)
        #print(rDat.decode('utf-8'), end='')
        if rDat == b'?':
            break
        elif rDat == b'>':
            txErr = 1
            break
    if txErr == 1:
        print("Error: programmer not ready to receive data.")
        break
    lin = bytes(line,'ascii')
    print(line,end='')
    ser.write(lin)
	

f.close()
ser.close()
