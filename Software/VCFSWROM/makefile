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

rom.out: exprom.o tsmon.o ehbasic.o namewriter.o
	$(LD) $(LDFLAGS) -T nofpulink.ld -Map rom.map -o rom.out tsmon.o exprom.o ehbasic.o namewriter.o

tsmon.o:
	$(AS) $(ASFLAGS)="tsmon.L68" -o tsmon.o tsmon.s

exprom.o:
	$(AS) $(ASFLAGS)="exprom.L68" -o exprom.o exprom.s

ehbasic.o:
	$(AS) --alternate $(ASFLAGS)="ehbasic.L68" -o ehbasic.o ehbasic.s

namewriter.o:
	$(AS) $(ASFLAGS)="namewriter.L68" -o namewriter.o namewriter.s

clean:
	-$(RM) *.o *.out *.L68 *.srec *.map

.PHONY: rebuild
rebuild:
	$(MAKE) clean
	$(MAKE) ROM

burn: rom.srec
	$(PYTHON) ..\..\Utilities\srecLoadWin.py rom.srec

ALL:
	$(MAKE) clean
	$(MAKE) ROM
	$(MAKE) burn

