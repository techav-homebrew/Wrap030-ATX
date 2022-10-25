AS=m68k-elf-as
ASFLAGS=-m68881 -march=68030 -mcpu=68030
CC=m68k-elf-gcc
CFLAGS=-c -nostdlib -nodefaultlibs -fno-builtin -m68030 -m68881 -nostartfiles -std=c99 -O2
LD=m68k-elf-ld
#LDFLAGS=-static -Ttext=0x00210000 -Tbss=0x00000400 -Trodata=00200000
LDFLAGS=-static -Tlinker.ld
OC=m68k-elf-objcopy
OCFLAGS=


DEPS=elf.h fat16.h hardware.h
OBJ=include/vector.o include/crt0.o diskload.o include/acia.o include/fat16.o include/ide.o include/malloc.o include/str.o include/endianswap.o

vector: include/vector.o
	$(AS) -o include/vector.o include/vector.s $(ASFLAGS)


crt0: include/crt0.o
	$(AS) -o include/crt0.o include/crt0.s $(ASFLAGS)


# output the compiled program as an SREC file for loading to ROM
diskload: $(OBJ)
#	$(CC) $(CFLAGS) -o $@ $^ $(OBJ)
	$(CC) $(CFLAGS) -o $@ $^
	$(LD) -o diskload.out $(OBJ) $(LDFLAGS)
#	$(OC) diskload.out -O binary diskload.sys
	$(OC) diskload.out -O srec diskload.srec $(OCFLAGS)

