
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

