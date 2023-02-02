


| MEMORY MAP
|  512kB    RAM (ROM Overlay)      0x0000,0000 - 0x0007,FFFF
|  512kB    RAM                    0x0008,0000 - 0x000F,FFFF
|  512kB    RAM                    0x0010,0000 - 0x0017,FFFF
|  512kB    RAM + Video Buffer     0x0018,0000 - 0x001F,FFFF
|  512kB    ROM (128kB, repeating) 0x0020,0000 - 0x0027,FFFF
|  512kB    [Empty,Bus Error]      0x0028,0000 - 0x002F,FFFF
|  512kB    Overlay Switch         0x0030,0000 - 0x0037,FFFF
|  512kB    ACIA                   0x0038,0000 - 0x003F,FFFF
| 1.99GB    [Repeat Above]         0x0040,0000 - 0x7FFF,FFFF
| 2.00GB    [Expansion]            0x8000,0000 - 0xFFFF,FFFF

| ROM overlay is enabled on reset and allows ROM to be read from the first page
| RAM can still be written to on Page 0 when overlay is enabled.
| Writing to any address on page 6 will toggle the overlay.
| Overlay should already be disabled before TSMON is started.

| ROM MAP
|   64kB    TSMON                  0x0020,0000 - 0x0020,FFFF
|   64kB    Enhanced BASIC         0x0021,0000 - 0x0021,FFFF



|    .equ expROM, romSector1

    .equ ramTop, 0x001FFFFF
    .equ stackTop, ramTop+1
|    .equ ramBot, 0x00000000



    .equ acia2offset, 8
    .equ aciaDatOffset, 4

|    .equ aciaSet, 0x16            | 8N1,÷64 (9600),no interrupts
    .equ aciaSet, 0x15            | 8N1,÷16 (38400),no interrupts



    .equ ideBase, 0x80200000
    .equ ideCommand, ideBase+0x0000
    .equ ideControl, ideBase+0x2000
    .equ ideDataRW, ideCommand+0x0
    .equ ideErrorRO, ideCommand+0x2
    .equ ideFeatureWO, ideCommand+0x2
    .equ ideSectorCountRW, ideCommand+0x4
    .equ ideLBALLRW, ideCommand+0x6
    .equ ideLBALHRW, ideCommand+0x8
    .equ ideLBAHLRW, ideCommand+0xa
    .equ ideLBAHHRW, ideCommand+0xC
    .equ ideStatusRO, ideCommand+0xE
    .equ ideCommandWO, ideCommand+0xE
    .equ ideAltStatusRO, ideControl+0xC
    .equ ideDevControlWO, ideControl+0xC
    .equ ideDevAddressRO, ideControl+0xF

    .equ ideCmdReadSect, 0x21             | read sector command
    .equ ideCmdNOP, 0x00             | disk no operation command

| Symbol .equates
    .equ BS, 0x08            | Backspace
    .equ CR, 0x0D            | Carriage Return
    .equ LF, 0x0A            | Line Feed
    .equ SPACE, 0x20            | Space
| WAIT:               EQU 'W'            | Wait Character (to suspend output)
    .equ WAIT, 'W'
    .equ ESC, 0x1B            | ASCII Escape (used by TM)
    .equ CTRL_A, 0x01            | Control_A forces return to monitor
    
|    .equ DATA, ramBot+0xC00  | Data origin
    .equ DATA, ramBot
    .equ BUFFEND, LNBUFF+MAXCHR-1 | End of line buffer

| Device addresses
    .equ STACK, stackTop       | stack pointer
    .equ ACIA_1, acia1Com       | console ACIA control
    .equ ACIA_2, acia2Com       | aux ACIA control (not used)
    .equ X_BASE, 0x08            | Start of exception vector table
    .equ TRAP_14, 0x4E4E          | Code for TRAP #14
    .equ MAXCHR, 64             | Length of line input buffer



    .equ trapGetChar, 0
    .equ trapPutChar, 1
    .equ trapNewLine, 2
    .equ trapGetParam, 3
    .equ trapPutString, 4
    .equ trapGetHexChar, 5
    .equ trapGetHexByte, 6
    .equ trapGetHexWord, 7
    .equ trapGetHexLong, 8
    .equ trapPutHexByte, 9
    .equ trapPutHexWord, 10
    .equ trapPutHexLong, 11
    .equ trapPutSpace, 12
    .equ trapGetLine, 13
    .equ trapTidyLine, 14
    .equ trapExecute, 15
    .equ trapRestore, 16

|******************************************************************************
| Generic macro for system calls

    .macro callSYS callNum
    move.l  %d1,%sp@-                   | save the working register
    move.b  #\callNum,%d1               | load syscall number
    trap    #0                          | call syscall handler
    move.l  %sp@+,%d1                   | restore the working register
    .endm

| uncomment to enable debug statements
| debug:
