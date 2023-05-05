PYTHON=python.exe
VASM=..\..\..\Utilities\vasm\vasmm68k_mot.exe
VFLAGS=-Fsrec -m68030 -m68882 -s37 -exec=START

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

ALL:
	$(MAKE) memtest2.S68

memtest2.S68:
	$(VASM) $(VFLAGS) -L memtest2.L68 -o memtest2.S68 memtest2.x68

burn: memtest2.S68
	$(PYTHON) ..\..\..\Utilities\srecLoadWin.py memtest2.S68

clean:
	-$(RM) *.L68 *.S68