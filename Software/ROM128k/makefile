AS=m68k-elf-as
ASFLAGS=-m68882 -march=68030 -mcpu=68030 --base-size-default-16 -alhms
#CC=m68k-elf-gcc
#CFLAGS=-nostdlib -nodefaultlibs -fno-builtin -m68030 -m68881 -nostartfiles -mpcrel -c
LD=m68k-elf-ld
LDFLAGS=
OC=m68k-elf-objcopy
OCFLAGS=
PYTHON=python

# make Windows happy
ifeq ($(OS),Windows_NT) 
RM = del /Q /F
CP = copy /Y
ifdef ComSpec
SHELL := $(ComSpec)
endif
ifdef COMSPEC
SHELL := $(COMSPEC)
endif
else
RM = rm -rf
CP = cp -f
endif

ROM: rom.out
	$(OC) $(OCFLAGS) rom.out -O srec rom.srec

rom.out: exprom.o tsmon.o ehbasic.o
	$(LD) $(LDFLAGS) -T nofpulink.ld -Map rom.map -o rom.out tsmon.o exprom.o ehbasic.o

FPUROM:	fpurom.out
	$(OC) $(OCFLAGS) fpurom.out -O srec fpurom.srec

fpurom.out: exprom.o tsmon.o fpubasic.o
	$(LD) $(LDFLAGS) -T fpulink.ld -Map fpurom.map -o fpurom.out tsmon.o exprom.o fpubasic.o

#ROM: rom.out
#	$(OC) $(OCFLAGS) rom.out -O srec rom.srec
#
#rom.out: exprom.o tsmon.o fpubasic.o
#	$(LD) $(LDFLAGS) -Map rom.map -o rom.out tsmon.o exprom.o

tsmon.o:
	$(AS) $(ASFLAGS)="tsmon.L68" -o tsmon.o tsmon.s

exprom.o:
	$(AS) $(ASFLAGS)="exprom.L68" -o exprom.o exprom.s

fpubasic.o:
	$(AS) $(ASFLAGS)="fpubasic.L68" -o fpubasic.o fpubasic.s

ehbasic.o:
	$(AS) --alternate $(ASFLAGS)="ehbasic.L68" -o ehbasic.o ehbasic.s

clean:
	-$(RM) *.o *.out *.L68 *.srec *.map

.PHONY: rebuild
rebuild:
	$(MAKE) clean
	$(MAKE) ROM

burn: rom.srec
	$(PYTHON) ..\..\Utilities\srecLoadWin.py rom.srec

fpuburn: fpurom.srec
	$(PYTHON) ..\..\Utilities\srecLoadWin.py fpurom.srec

ALL:
	$(MAKE) clean
	$(MAKE) ROM
	$(MAKE) burn

loadbasic: rambasic.srec
	$(PYTHON) ..\..\Utilities\srecLoadRAMwin.py COM6 rambasic.srec

rambasic.srec: rambasic.out
	$(OC) $(OCFLAGS) rambasic.out -O srec rambasic.srec

rambasic.out: fpubasic.o
	$(LD) -T rambasic.ld -Map rambasic.map -o rambasic.out fpubasic.o