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
	$(MAKE) memtest3.S68

memtest3.S68:
	$(VASM) $(VFLAGS) -L memtest3.L68 -o memtest3.S68 memtest3.x68

burn: memtest3.S68
	$(PYTHON) ..\..\..\Utilities\srecLoadWin.py memtest3.S68

clean:
	-$(RM) *.L68 *.S68