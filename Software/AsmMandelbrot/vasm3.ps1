# ..\..\Utilities\vasm\vasmm68k_mot.exe -Felf -L AsmMandelbrot.L68 -o AsmMandelbrot.elf -m68030 -m68882 AsmMandelbrot.x68
# m68k-elf-ld -A 68030 -T linker.ld -s -M -n -static -o AsmMandelbrot.BIN AsmMandelbrot.elf
..\..\Utilities\vasm\vasmm68k_mot.exe -Fsrec -L AsmMandelbrot3.L68 -o AsmMandelbrot3.S68 -m68030 -m68882 -s28 -exec=start AsmMandelbrot3.x68