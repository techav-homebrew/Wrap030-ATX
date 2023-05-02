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
	$(MAKE) comtest.S68

comtest.S68:
	$(VASM) $(VFLAGS) -L comtest.L68 -o comtest.S68 comtest.x68

burn: comtest.S68
	$(PYTHON) ..\..\..\Utilities\srecLoadWin.py comtest.S68

clean:
	-$(RM) *.L68 *.S68