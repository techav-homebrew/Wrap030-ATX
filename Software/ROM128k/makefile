AS=m68k-elf-as.exe
ASFLAGS=-m68882 -march=68030 -mcpu=68030 --base-size-default-16 -alhms
#CC=m68k-elf-gcc.exe
#CFLAGS=-nostdlib -nodefaultlibs -fno-builtin -m68030 -m68881 -nostartfiles -mpcrel -c
LD=m68k-elf-ld.exe
LDFLAGS=-T linker.ld
OC=m68k-elf-objcopy
OCFLAGS=
PYTHON=python.exe

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

rom.out: exprom.o tsmon.o fpubasic.o
	$(LD) $(LDFLAGS) -Map rom.map -o rom.out tsmon.o exprom.o

tsmon.o:
	$(AS) $(ASFLAGS)="tsmon.L68" -o tsmon.o tsmon.s

exprom.o:
	$(AS) $(ASFLAGS)="exprom.L68" -o exprom.o exprom.s

fpubasic.o:
	$(AS) $(ASFLAGS)="fpubasic.L68" -o fpubasic.o fpubasic.s

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
