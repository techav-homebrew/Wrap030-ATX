# ..\..\Utilities\vasm\vasmm68k_mot.exe -Fsrec -L FPUBasic030.L68 -o FPUBasic030.S68 -m68030 -m68882 -s37 FPUBasic030.asm
# ..\..\Utilities\vasm\vasmm68k_mot.exe -Faout -o FPUBasic030.a -m68030 -m68882 FPUBasic030.asm
..\..\Utilities\vasm\vasmm68k_mot.exe -Felf -L FPUBasic030.L68 -o FPUBasic030.elf -m68030 -m68882 FPUBasic030.asm
m68k-elf-ld -A 68030 -T linker.ld -s -M -n -static -o FPUBASIC.BIN FPUBasic030.elf