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
	$(MAKE) memtest.S68

memtest.S68:
	$(VASM) $(VFLAGS) -L memtest.L68 -o memtest.S68 memtest.x68

burn: memtest.S68
	$(PYTHON) ..\..\..\Utilities\srecLoadWin.py memtest.S68

clean:
	-$(RM) *.L68 *.S68