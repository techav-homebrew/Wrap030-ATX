|    .equ acia2offset, 8
|    .equ aciaDatOffset, 4

|    .equ aciaSet, 0x16            | 8N1,÷64 (9600),no interrupts
|    .equ aciaSet, 0x15            | 8N1,÷16 (38400),no interrupts



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
|    .equ ACIA_1, acia1Com       | console ACIA control
|    .equ ACIA_2, acia2Com       | aux ACIA control (not used)
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
