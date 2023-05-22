| MONITOR.X68
| X68K PC-1.7 Copyright (C) Teeside Polytechnic 1989
| Defaults:
|       ORG $0/FORMAT/OPT A,BRL,CEX,CL,FRL,MC,MD,NOMEX,NOPCO

| TSBUG2 - 68000 monitor - version of 23 July 1986
| Modified for Wrap030 project,techav 2021/12/26
| Translated to GNU AS syntax,techav 2023/01/30

| ***************************************************************************
| linker declarations

        .global LNBUFF
        .global BUFFPT
        .global PARAMTR
        .global ECHO
        .global U_CASE
        .global UTAB
        .global CN_IVEC
        .global CN_OVEC
        .global TSK_T
        .global BP_TAB
        .global BUFFER
        .global dskBUF
        .global startHeap
        .global _start
        .extern EXTROM
|        .extern acia1Com
|        .extern acia1Dat
|        .extern acia2Com
|        .extern acia2Dat
        .extern spioPort
        .extern spioCOM0
        .extern spioCOM1
        .extern spioLPT0
        .extern comRegRX
        .extern comRegTX
        .extern comRegIER
        .extern comRegIIR
        .extern comRegFCR
        .extern comRegLCR
        .extern comRegMCR
        .extern comRegLSR
        .extern comRegMSR
        .extern comRegSPR
        .extern com0lsr
        .extern com0tx
        .extern com0mcr
        .extern comRegDivLo
        .extern comRegDivHi
        .extern busCtrlPort
        .extern dramCtrlPort
        .extern vidBase
        .extern vidBuf0
        .extern vidBuf1
        .extern vidReg

| ***************************************************************************
| global variables (BSS section) in memory
    .section bss,"w"

LNBUFF:             DS.B MAXCHR        | Input line buffer
BUFFPT:             DS.L 1             | Pointer to line buffer
PARAMTR:            DS.L 1             | Last parameter from line buffer
ECHO:               DS.B 1             | When clear this enable input echo
U_CASE:             DS.B 1             | Flag for uppercase conversion
UTAB:               DS.L 1             | Pointer to user command table
CN_IVEC:            DS.L 1             | Pointer to console input DCB
CN_OVEC:            DS.L 1             | Pointer to console output DCB
TSK_T:              DS.W 37            | Frame for D0-D7,A0-A6,USP,SSP,SW,PC
BP_TAB:             DS.W 24            | Breakpoint table
FIRST:              DS.B 512           | DCB area
BUFFER:             DS.B 256           | 256 bytes for I/O Buffer
dskBUF:             DS.W 256           | 512 byte disk sector buffer

    .even
startHeap:
| ***************************************************************************

	.include "TSMON_Constants.INC"
        .include "macros.inc"

| ***************************************************************************
| Monitor cold start vector table
        .section text,"ax"
VECTOR:
        dc.L stackTop                   | initial SP
        dc.L _start                     | initial PC

| Monitor cold start initialization
_start:
CheckOverlay:
        lea     spioCOM0,%a0            | get pointer to COM0
        initCOM %a0                     | call macro to initialize COM0
        lea     spioCOM1,%a0            | get pointer to COM1
        initCOM %a0                     | call macro to initialize COM1
        debugPrint 0x0d                 | output a newline first
        debugPrint 0x0a
initMemController:
        move.l  #dramCtrlPort,%d0       | get base address to DRAM register
        ori.l   #0x0900,%d0             | configure DRAM for 11b Row, 10b Col
        move.l  %d0,%a0                 | get pointer
        move.l  %d0,%a0@                | write to controller
|        move.L #0x55AA55AA,%d0          | test pattern
|        move.L #ramBot,%a0              | get base of memory
|        move.L %d0,%a0@                 | write to first memory address
|        move.l %a0@,%d1                 | read back pattern
|        cmp.L  %d1,%d0                  | check if they match
|        beq.s  ClearMainMemory                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | if matching, then overlay is already disabled
|ClearOverlay:
|        move.B #0,overlayPort           | disable startup overlay
ClearMainMemory:
        lea    stackTop,%a0             | get top of memory space
        move.l %a0,%d0                  | copy to loop counter
        lsr.l  #2,%d0                   | convert into long word count
        swap   %d0                      | get count of 64k long word pages
        move.w %d0,%d1                  | copy that count to D1 as page counter
        subq.w #1,%d1                   | decrement by 1 to avoid an early bus error
        eor.l  %d2,%d2                  | zero out D2 to use for zeroing memory
clrRamPgLp:
        move.w #0xffff,%d0              | use D0 as count of long words to copy
clrRamLWlp:
        move.l %d2,%a0@-                | zero out memory
        dbra   %d0,clrRamLWlp           | loop until this page is cleared
        debugPrint '.'                  | status display
        dbra   %d1,clrRamPgLp           | loop until all pages cleared
        debugPrint '-'                  | status indicator: memory clear complete

InitRamVectors:
        move.l #ramBot,%a0              | get bottom of RAM
        move.l #stackTop,%a0@(0)        | fill in initial SP
|        move.l #_start,%a0@(4)          | and initial PC ... just in case
        move.l #COLD,%a0@(4)            | load the TSMON "COLD" subroutine into
                                        | the initial PC restart vector at the 
                                        | base of memory so that we only clear
                                        | memory on initial power on
                                        | if we reset later, skip the memory
                                        | initialization and jump ahead to 
                                        | restarting the monitor
                                        | (this requires coordination with the
                                        | main board glue logic, which should
                                        | be made to not clear the overlay 
                                        | register when the reset signal is
                                        | asserted)
        debugPrint ':'                  | status indicator: pre-monitor complete

| ***************************************************************************
| This is the main program which assembles a command in the line
| buffer,removes leading/embedded spaces,and interprets it by matching
| it with a command in the user table or the built-in table COMTAB
| All variables are specified with respect to A6

COLD:                                   | Cold entry point for monitor
        MOVE.L  #stackTop,%a7           | Manually set stack pointer for Emulator
        LEA     DATA,%a6                | A6 points to data area
        CLR.L   %a6@(UTAB)              | Reset pointer to user extension table
        CLR.B   %a6@(ECHO)              | Set automatic character echo
        CLR.B   %a6@(U_CASE)            | Clear case conversion flag (UC<-LC)
        BSR     SETACIA                 | Setup ACIAs
        BSR     X_SET                   | Setup exception table
        BSR     SET_DCB                 | Setup DCB table in RAM
        LEA     %pc@(BANNER),%a4        | Point to banner
        BSR     HEADING                 | and print heading
        LEA     EXTROM,%a0              | A0 points to expansion ROM
        MOVE.L  %a0@,%d0                | Read first longword in extension ROM          
        CMP.L   #0x524f4d32,%d0         | If extension begins with 'ROM2' then
        BNE.S   NO_EXT                  | call the subroutine at EXT_ROM+8
        MOVEM.L %a0-%a6/%d0-%d7,%sp@-   | caller save all registers just in case
        JSR     %a0@(8)                 | else continue
        MOVEM.L %sp@+,%a0-%a6/%d0-%d7   | restore all registers after ROM2 initialization

NO_EXT:
        NOP                             | Two NOPs to allow for a future
        NOP                             | call to an initialization routine
WARM:
        CLR.L   %d7                     | Warm entry point - clear error flag
        BSR     NEWLINE                 | Print a newline
        BSR     GETLINE                 | Get a command line
        BSR     TIDY                    | Tidy up input buffer contents
        BSR     EXECUTE                 | Interpret command
        BRA     WARM                    | Repeat indefinitely

| ***************************************************************************

| Some initialization and basic routines

SETACIA:                                | Setup ACIA parameters
|        LEA     ACIA_1,%a0              | A0 points to console ACIA
|        MOVE.B  #0x03,%a0@              | Reset ACIA 1
|        MOVE.B  #0x03,%a0@(acia2offset) | Reset ACIA 2
|        MOVE.B  #aciaSet,%a0@           | Configure ACIA 1
|        MOVE.B  #aciaSet,%a0@(acia2offset)      | Configure ACIA 2
        lea     spioCOM0,%a0            | get pointer to COM0
        initCOM %a0                     | call macro to initialize COM0
        lea     spioCOM1,%a0            | get pointer to COM1
        initCOM %a0                     | call macro to initialize COM1
        RTS

NEWLINE:                                | Move cursor to start of newline
        MOVEM.L %a4,%a7@-               | Save A4
        LEA     %pc@(CRLF),%a4          | Point to CR/LF string
        BSR.S   PSTRING                 | Print it
        MOVEM.L %a7@+,%a4               | Restore A4
        RTS                             | Return

PSTRING:                                | Display the string pointed at by A4
        MOVE.L  %d0,%a7@-               | Save D0
PS1:
        MOVE.B  %a4@+,%d0               | Get character to be printed
        BEQ.S   PS2                     | If null then return
        BSR     PUTCHAR                 | Else print it
        BRA     PS1                     | Continue
PS2:
        MOVE.L %a7@+,%d0                | Restore %d0 and exit
        RTS

HEADING:
        BSR     NEWLINE                 | Same as PSTRING but with newline
        BSR     PSTRING
        BRA     NEWLINE

| ***************************************************************************

| GETLINE    inputs a string of characters into a line buffer
| A3 points to next free entry in line buffer
| A2 points to end of buffer
| A1 points to start of buffer
| D0 holds character to be stored

GETLINE:

        LEA     %a6@(LNBUFF),%a1        | A1 points to start of line buffer
        LEA     %a1@,%a3                | A3 points to start (initially)
        LEA     %a1@(MAXCHR),%a2        | A2 points to end of buffer
GETLN2:

        BSR     GETCHAR                 | Get a character
        CMP.B   #CTRL_A,%d0             | If control_A then reject this line
        BEQ.S   GETLN5                  | and get another line
        CMP.B   #BS,%d0                 | If backspace the move back pointer
        BNE.S   GETLN3                  | Else skip past wind-back routine
        CMP.L   %a1,%a3                 | First check for empty buffer
        BEQ     GETLN2                  | If buffer empty then continue
        LEA     %a3@(-1),%a3            | Else decrement buffer pointer
        BRA     GETLN2                  | and continue with next character
GETLN3:

        MOVE.B  %d0,%a3@+               | Store character and update pointer
        CMP.B   #CR,%d0                 | Test for command terminator
        BNE.S   GETLN4                  | If not CR then skip past exit
        BRA     NEWLINE                 | Else new line before next operation
GETLN4:

        CMP.L   %a2,%a3                 | Test for buffer overflow
        BNE     GETLN2                  | If buffer not full then continue
GETLN5:

        BSR     NEWLINE                 | Else move to next line and
        BRA     GETLINE                 | repeat this routine

| ***************************************************************************

| TIDY    cleans up the line buffer by removing leading spaces and multiple
| spaces between parameters. At the end of TIDY,BUFFPT points to
| the first parameter following the command
| A0 = pointer to line buffer
| A1 = pointer to cleaned up buffer

TIDY:
        LEA %a6@(LNBUFF),%a0              | A0 points to line buffer
        LEA %a0@,%a1                    | A1 points to start of line buffer
TIDY1:
        MOVE.B %a0@+,%d0                | Read character from line buffer
        CMP.B #SPACE,%d0                | Repeat until the first non-space
        BEQ TIDY1                      | character is found
        LEA %a0@(-1),%a0                  | Move pointer back to first char
TIDY2:
        MOVE.B %a0@+,%d0                | Move the string left to remove
        MOVE.B %d0,%a1@+                | any leading spaces
        CMP.B #SPACE,%d0                | Test for embedded space
        BNE.S TIDY4                    | If not space then test for EOL
TIDY3:
        CMP.B #SPACE,%a0@+             | If space skip multiple embedded
        BEQ TIDY3                      | spaces
        LEA %a0@(-1),%a0                  | Move back pointer
TIDY4:
        CMP.B #CR,%d0                   | Test for end_of_line (EOL)
        BNE TIDY2                      | If not EOL then read next char
        LEA %a6@(LNBUFF),%a0              | Restore buffer pointer
TIDY5:
        CMP.B #CR,%a0@                 | Test for EOL
        BEQ.S TIDY6                    | If EOL then exit
        CMP.B #SPACE,%a0@+             | Test for delimiter
        BNE TIDY5                      | Repeat until delimiter or EOL
TIDY6:
        MOVE.L %a0,%a6@(BUFFPT)           | Update buffer pointer
        RTS

| ***************************************************************************

| EXECUTE    matches the first command in the line buffer with the
| commands in a command table. An external table pointed at by
| UTAB is searched first and then the in-built table,COMTAB.

EXECUTE:
        TST.L %a6@(UTAB)                 | Test pointer to user table
        BEQ.S EXEC1                    | If clear then try built-in table
        MOVE.L %a6@(UTAB),%a3             | Else pick up pointer to user table
        BSR.S SEARCH                   | Look for command in user table
        BCC.S EXEC1                    | If not found then try internal table
        MOVE.L %a3@,%a3                 | Else get absolute address of command
        JMP %a3@                       | from user table and execute it

EXEC1:
        LEA %pc@(COMTAB),%a3              | Try built-in command table
        BSR.S SEARCH                   | Look for command in built-in table
        BCS.S EXEC2                    | If found then execute command
        LEA %pc@(ERMES2),%a4              | Else print "invalid command"
        BRA.L PSTRING                  | and return
EXEC2:
        MOVE.L %a3@,%a3                 | Get the relative command address
        LEA %pc@(COMTAB),%a4              | pointed at by A3 and add it to
        ADD.L %a4,%a3                    | the PC to generate the actual
        JMP %a3@                       | command address. Then execute it.

SEARCH:                                | Match the command in the line buffer
        CLR.L %d0                       | with command table pointed at by A3
        MOVE.B %a3@,%d0                 | Get the first character in the
        BEQ.S SRCH7                    | current entry. If zero then exit
        LEA %a3@(6,%d0:W),%a4              | Else calculate address of next entry
        MOVE.B %a3@(1),%d1                | Get number of characters to match
        LEA %a6@(LNBUFF),%a5              | A5 points to command in line buffer
        MOVE.B %a3@(2),%d2                | Get first character in this entry
        CMP.B %a5@+,%d2                 | from the table and match with buffer
        BEQ.S SRCH3                    | If match then try rest of string
SRCH2:
        MOVE.L %a4,%a3                   | Else get address of next entry
        BRA SEARCH                     | and try the next entry in the table
SRCH3:
        SUB.B #1,%d1                    | One less character to match
        BEQ.S SRCH6                    | If match counter zero then all done
        LEA %a3@(3),%a3                   | Else point to next character in table
SRCH4:
        MOVE.B %a3@+,%d2                | Now match a pair of characters
        CMP.B %a5@+,%d2
        BNE SRCH2                      | If no match then try next entry
        SUB.B #1,%d1                    | Else decrement match counter and
        BNE SRCH4                      | repeat until no chars left to match
SRCH6:
        LEA %a4@(-4),%a3                  | Calculate address of command entry
        OR.B #1,%ccr                    | point. Mark carry flag as success
        RTS                            | and return
SRCH7:
        AND.B #0xFE,%ccr                 | Fail - clear carry to indicate
        RTS                            | command not found and return

| ***************************************************************************

| Basic input routines
| HEX    = Get one     hexadecimal character    into D0
| BYTE    = Get two     hexadecimal characters into D0
| WORD    = Get four    hexadecimal characters into D0
| LONGWD    = Get eight hexadecimal characters into D0
| PARAM    = Get a longword from the line buffer into D0
| Bit 0 of %d7 is set to indicate a hexadecimal input error

HEX:
        BSR GETCHAR                    | Get a character from input device
        SUB.B #0x30,%d0                  | Convert to binary
        BMI.S NOT_HEX                  | If less than #30 then exit with error
        CMP.B #0x09,%d0                  | Else test for number (0 to 9)
        BLE.S HEX_OK                   | If number then exit - success
        SUB.B #0x07,%d0                  | Else convert letter to hex
        CMP.B #0x0F,%d0                  | If character in range "A" to "F"
        BLE.S HEX_OK                   | then exit successfully
NOT_HEX:
        OR.B #1,%d7                     | Else set error flag
HEX_OK:
        RTS                            | and return

BYTE:
        MOVE.L %d1,%a7@-                | Save D1
        BSR HEX                        | Get first character
        ASL.B #4,%d0                    | Move it to MS nybble position
        MOVE.B %d0,%d1                   | Save MS nybble in D1
        BSR HEX                        | Get second hex character
        ADD.B %d1,%d0                    | Merge MS and LS nybbles
        MOVE.L %a7@+,%d1                | Restore D1
        RTS 

WORD:
        BSR BYTE                       | Get upper order byte
        ASL.W #8,%d0                    | Move it to MS position
        BRA BYTE                       | Get LS byte and return

LONGWD:
        BSR WORD                       | Get upper order word
        SWAP %d0                        | Move it to MS position
        BRA WORD                       | Get lower order word and return

| ***************************************************************************

| PARAM reads a parameter from the line buffer and puts it in both
| %a6@(PARAMTR) and D0. Bit 1 of %d7 is set on error

PARAM:
        MOVE.L %d1,%a7@-                | Save D1
        CLR.L %d1                       | Clear input accumulator
        MOVE.L %a6@(BUFFPT),%a0           | A0 points to parameter in buffer
PARAM1:
        MOVE.B %a0@+,%d0                | Read character from line buffer
        CMP.B #SPACE,%d0                | Test for delimiter
        BEQ.S PARAM4                   | The permitted delimiter is a
        CMP.B #CR,%d0                   | space or a carriage return
        BEQ.S PARAM4                   | Exit on either space or C/R
        ASL.L #4,%d1                    | Shift accumulated result 4 bits left
        SUB.B #0x30,%d0                  | Convert new character to hex
        BMI.S PARAM5                   | If less than $30 then not-hex
        CMP.B #0x09,%d0                  | If less than 10
        BLE.S PARAM3                   | then continue
        SUB.B #0x07,%d0                  | Else assume $A - $F
        CMP.B #0x0F,%d0                  | If more than $F
        BGT.S PARAM5                   | then exit to error on not-hex
PARAM3:
        ADD.B %d0,%d1                    | Add latest nybble to total in D1
        BRA PARAM1                     | Repeat until delimiter found
PARAM4: 
        MOVE.L %a0,%a6@(BUFFPT)           | Save pointer in memory
        MOVE.L %d1,%a6@(PARAMTR)          | Save parameter in memory
        MOVE.L %d1,%d0                   | Put parameter in %d0 for return
        BRA.S PARAM6                   | Return without error
PARAM5:
        OR.B #2,%d7                     | Set error flag before return
PARAM6:
        MOVE.L %a7@+,%d1                | Restore working register
        RTS                            | Return with error

| ***************************************************************************

| Output routines
| OUT1X    = print one     hexadecimal character
| OUT2X    = print two     hexadecimal characters
| OUT4X    = print four    hexadecimal characters
| OUT8X    = print eight   hexadecimal characters
| In each case,the data to be printed is in D0

OUT1X:
        MOVE.B %d0,%a7@-                | Save D0
        AND.B #0x0F,%d0                  | Mask off MS nybble
        ADD.B #0x30,%d0                  | Convert to ASCII
        CMP.B #0x39,%d0                  | ASCII = HEX + $30
        BLS.S OUT1X1                   | If ASCII <= $39 then print and exit
        ADD.B #0x07,%d0                  | Else ASCII: = HEX + 7
OUT1X1:
        BSR PUTCHAR                    | Print the character
        MOVE.B %a7@+,%d0                | Restore D0
        RTS

OUT2X:
        ROR.B #4,%d0                    | Get MS nybble in LS position
        BSR OUT1X                      | Print MS nybble
        ROL.B #4,%d0                    | Restore LS nybble
        BRA OUT1X                      | Print LS nybble and return

OUT4X:
        ROR.W #8,%d0                    | Get MS byte in LS position
        BSR OUT2X                      | Print MS byte
        ROL.W #8,%d0                    | Restore LS byte
        BRA OUT2X                      | Print LS byte and return

OUT8X:
        SWAP %d0                        | Get MS word in LS position
        BSR OUT4X                      | Print MS word
        SWAP %d0                        | Restore LS word
        BRA OUT4X                      | Print LS word and return

| ***************************************************************************

| JUMP causes execution to begin at the address in the line buffer

JUMP:
        BSR PARAM                      | Get address from buffer
        TST.B %d7                       | Test for input error
        BNE.S JUMP1                    | If error flag not zero then exit
        TST.L %d0                       | Else test for missing address
        BEQ.S JUMP1                    | field. If no address then exit
        MOVE.L %d0,%a0                   | Put jump address in A0 and call the
        JMP %a0@                       | subroutine. User to supply RTS!!
JUMP1:
        LEA %pc@(ERMES1),%a4              | Here for error - display error
        BRA PSTRING                    | message and return

| ***************************************************************************

| Display the contents of a memory location and modify it

MEMORY:
        BSR PARAM                      | Get start address from line buffer
        TST.B %d7                       | Test for input error
        BNE.S MEM3                     | If error then exit
        MOVE.L %d0,%a3                   | A3 points to location to be opened
MEM1:
        BSR NEWLINE
        BSR.S ADR_DAT                  | Print current address and contents
        BSR.S PSPACE                   | update pointer,A3,and O/P space
        BSR GETCHAR                    | Input char to decide next action
        CMP.B #CR,%d0                   | If carriage return then exit
        BEQ.S MEM3                     | Exit
        CMP.B #'-',%d0                  | If "-" then move back
        BNE.S MEM2                     | Else skip wind-back procedure
        LEA %a3@(-4),%a3                  | Move pointer back 2+2
        BRA MEM1                       | Repeat until carriage return
MEM2:
        CMP.B #SPACE,%d0                | Test for space (= new entry)
        BNE.S MEM1                     | If not space then repeat
        BSR WORD                       | Else get new word to store
        TST.B %d7                       | Test for input error
        BNE.S MEM3                     | If error then exit
        MOVE.W %d0,%a3@(-2)               | Store new word
        BRA MEM1                       | Repeat until carriage return
MEM3:
        RTS

ADR_DAT:
        MOVE.L %d0,%a7@-                | Print the contents of A3
        MOVE.L %a3,%d0                   | word pointed at by A3
        BSR OUT8X                      | and print current address
        BSR.S PSPACE                   | Insert delimiter
        MOVE.W %a3@,%d0                 | Get data at this address in D0
        BSR OUT4X                      | and print it
        LEA %a3@(2),%a3                   | Point to next address to display
        MOVE.L %a7@+,%d0                | Restore D0
        RTS

PSPACE:
        MOVE.B %d0,%a7@-                | Print a single space
        MOVE.B #SPACE,%d0
        BSR PUTCHAR
        MOVE.B %a7@+,%d0
        RTS

| ***************************************************************************

| LOAD    Loads data formatted in hexadecimal "S" record format from Port 2
| NOTE - I/O is automatically redirected to the aux port for
| loader functions. S1 or S2 records accepted

LOAD:
        MOVE.L %a6@(CN_OVEC),%a7@-       | Save current output device name
        MOVE.L %a6@(CN_IVEC),%a7@-       | Save current input device name
        MOVE.L #DCB4,%a6@(CN_OVEC)       | Set up aux ACIA as output
        MOVE.L #DCB3,%a6@(CN_IVEC)       | Set up aux ACIA as input
        ADD.B #1,%a6@(ECHO)              | Turn off character echo
        BSR NEWLINE                    | Send newline to host
        BSR DELAY                      | Wait for host to "settle"
        BSR DELAY
        MOVE.L %a6@(BUFFPT),%a4           | Any string in the line buffer is
LOAD1:
        MOVE.B %a4@+,%d0                | transmitted to the host computer
        BSR PUTCHAR                    | before the loading begins
        CMP.B #CR,%d0                   | Read from the buffer until EOL
        BNE LOAD1
        BSR NEWLINE                    | Send newline before loading
LOAD2:
        BSR GETCHAR                    | Records from the host must begin
        CMP.B #'S',%d0                  | with S1/S2 (data) or S9/S8 (term)
        BNE.S LOAD2                    | Repeat GETCHAR until char == "S"
        BSR GETCHAR                    | Get character after "S"
        CMP.B #'9',%d0                  | Test for the two terminators S9/S8
        BEQ.S LOAD3                    | If S9 record then exit else test
        CMP.B #'8',%d0                  | for S8 terminator. Fall through to
        BNE.S LOAD6                    | exit on S8 else continue search
LOAD3:                                 | Exit point from LOAD
        MOVE.L %a7@+,%a6@(CN_IVEC)       | Clean up by restoring input device
        MOVE.L %a7@+,%a6@(CN_OVEC)       | and output device name
        CLR.B %a6@(ECHO)                 | Restore input character echo
        BTST #0,%d7                     | Test for input errors
        BEQ.S LOAD4                    | If no I/P error then look at checksum
        LEA %pc@(ERMES1),%a4              | Else point to error message
        BSR PSTRING                    | Print it
LOAD4:
        BTST #3,%d7                     | Test for checksum error
        BEQ.S LOAD5                    | If clear then exit
        LEA %pc@(ERMES3),%a4              | Else point to error message
        BSR PSTRING                    | Print it and return
LOAD5:
        RTS
LOAD6:
        CMP.B #'1',%d0                  | Test for S1 record
        BEQ.S LOAD6A                   | If S1 record then read it
        CMP.B #'2',%d0                  | Else test for S2 record
        BNE.S LOAD2                    | Repeat until valid header found
        CLR.B %d3                       | Read the S2 byte count and address,
        BSR.S LOAD8                    | clear the checksum
        SUB.B #4,%d0                    | Calculate size of data field
        MOVE.B %d0,%d2                   | %d2 contains data bytes to read
        CLR.L %d0                       | Clear address accumulator
        BSR.S LOAD8                    | Read most sig byte of address
        ASL.L #8,%d0                    | Move it one byte left
        BSR.S LOAD8                    | Read the middle byte of address
        ASL.L #8,%d0                    | Move it one byte left
        BSR.S LOAD8                    | Read least sig byte of address
        MOVE.L %d0,%a2                   | A2 points to destination of record
        BRA.S LOAD7                    | Skip past S1 header loader
LOAD6A:
        CLR.B %d3                       | S1 record found - clear checksum
        BSR.S LOAD8                    | Get byte and update checksum
        SUB.B #3,%d0                    | Subtract 3 from record length
        MOVE.B %d0,%d2                   | Save byte count in D2
        CLR.L %d0                       | Clear address accumulator
        BSR.S LOAD8                    | Get MS byte of load address
        ASL.L #8,%d0                    | Move it to MS position
        BSR.S LOAD8                    | Get LS byte in D2
        MOVE.L %d0,%a2                   | A2 points to destination of data
LOAD7:
        BSR.S LOAD8                    | Get byte of data for loading
        MOVE.B %d0,%a2@+                | Store it
        SUB.B #1,%d2                    | Decrement byte counter
        BNE LOAD7                      | Repeat until count = 0
        BSR.S LOAD8                    | Read checksum
        ADD.B #1,%d3                    | Add 1 to total checksum
        BEQ LOAD2                      | If zero then start next record
        OR.B #0b00001000,%d7             | Else set checksum error bit
        BRA LOAD3                      | restore I/O devices and return
LOAD8:
        BSR BYTE                       | Get a byte
        ADD.B %d0,%d3                    | Update checksum
        RTS                            | and return

| ***************************************************************************

| DUMP    Transmit S1 formatted records to host computer
| A3 = Starting address of data block
| A2 = End address of data block
| %d1 = Checksum
| %d2 = Current record length

DUMP:
        BSR RANGE                      | Get start and end address
        TST.B %d7                       | Test for input error
        BEQ.S DUMP1                    | If no error then continue
        LEA %pc@(ERMES1),%a4              | Else point to error message
        BRA PSTRING                    | print it and return
DUMP1:
        CMP.L %a3,%d0                    | Compare start and end addresses
        BPL.S DUMP2                    | If positive then start < end
        LEA %pc@(ERMES7),%a4              | Else print error message
        BRA PSTRING                    | and return
DUMP2:
        MOVE.L %a6@(CN_OVEC),%a7@-       | Save name of current output device
        MOVE.L #DCB4,%a6@(CN_OVEC)       | Set up Port 2 as output device
        BSR NEWLINE                    | Send newline to host and wait
        BSR DELAY
        MOVE.L %a6@(BUFFPT),%a4           | Before dumping,send any string
DUMP3:
        MOVE.B %a4@+,%d0                | in e input buffer to the host
        BSR PUTCHAR                    | Repeat
        CMP.B #CR,%d0                   | Transmit char from buffer to host
        BNE DUMP3                      | Until char = C/R
        BSR NEWLINE
        BSR.S DELAY                    | Allow time for host to settle
        ADDQ.L #1,%a2                   | A2 contains length of record + 1
DUMP4:
        MOVE.L %a2,%d2                   | %d2 points to end address
        SUB.L %a3,%d2                    | %d2 contains bytes left to print
        CMP.L #17,%d2                   | If this is not a full record of 16
        BCS.S DUMP5                    | then load %d2 with the record size
        MOVEQ #16,%d2                   | Else preset byte count to 16
DUMP5:
        LEA %pc@(HEADER),%a4              | Print header
        BSR PSTRING                    | Print header
        CLR.B %d1                       | Clear checksum
        MOVE.B %d2,%d0                   | Move record length to output register
        ADD.B #3,%d0                    | Length includes address + count
        BSR.S DUMP7                    | Print number of bytes in record
        MOVE.L %a3,%d0                   | Get start address to be printed
        ROL.W #8,%d0                    | Get MS byte in LS position
        BSR.S DUMP7                    | Print MS byte of address
        ROR.W #8,%d0                    | Restore LS byte
        BSR.S DUMP7                    | Print LS byte of address
DUMP6:
        MOVE.B %a3@+,%d0                | Get data byte to be printed
        BSR.S DUMP7                    | Print it
        SUB.B #1,%d2                    | Decrement byte count
        BNE DUMP6                      | Repeat until all this record printed
        NOT.B %d1                       | Complement checksum
        MOVE.B %d1,%d0                   | Move to output register
        BSR.S DUMP7                    | Print checksum
        BSR NEWLINE
        CMP.L %a2,%a3                    | Have all records been printed?
        BNE DUMP4                      | Repeat until all done
        LEA %pc@(TAIL),%a4                | Point to message tail (S9 record)
        BSR PSTRING                    | Print it
        MOVE.L %a7@+,%a6@(CN_OVEC)       | Restore name of output device
        RTS                            | and return
DUMP7:
        ADD.B %d0,%d1                    | Update checksum,transmit byte
        BRA OUT2X                      | to host and return

RANGE:                                 | Get the range of addresses to be
        CLR.B %d7                       | transmitted from the buffer
        BSR PARAM                      | Get starting address
        MOVE.L %d0,%a3                   | Set up start address in A3
        BSR PARAM                      | Get end address
        MOVE.L %d0,%a2                   | Set up end address in A2
        RTS

DELAY:                                 | Provide a time delay for the host
        MOVEM.L %d0/%a4,%a7@-            | to settle. Save working registers
        MOVE.L #0x4000,%d0               | Set up delay constant
DELAY1:
        SUB.L #1,%d0                    | Count down    (8 clk cycles)
        BNE DELAY1                     | Repeat until zero    (10 clk cycles)
        MOVEM.L %a7@+,%d0/%a4            | Restore working registers
        RTS

| ***************************************************************************

| TM    Enter transparent mode (All communication to go from terminal to
| the host processor until escape sequence entered).
| End sequence = ESC,E.
| A newline is sent to the host to "clear it down".

TM:                                    | 
|        MOVE.B #0x55,ACIA_1                     | Force RTS* high to re-route data
        andi.b  #0xfd,com0mcr                   | set RTS high
        ADD.B #1,%a6@(ECHO)                     | Turn off character echo
TM1:
        BSR GETCHAR                             | Get character
        CMP.B #ESC,%d0                          | Test for end of TM mode
        BNE TM1                                 | Repeat until first escape character
        BSR GETCHAR                             | Get second character
        CMP.B #'E',%d0                          | If second char = E then exit TM
        BNE TM1                                 | Else continue
        MOVE.L %a6@(CN_OVEC),%a7@-              | Save output port device name
        MOVE.L #DCB4,%a6@(CN_OVEC)              | Get name of host port (aux port)
        BSR NEWLINE                             | Send newline to host to clear it
        MOVE.L %a7@+,%a6@(CN_OVEC)              | Restore output device port name
        CLR.B %a6@(ECHO)                        | Restore echo mode
|        MOVE.B #aciaSet,ACIA_1                  | Restore normal ACIA mode (RTS* low)
        ori.b   #0x02,com0mcr                   | set RTS low
        RTS

| ***************************************************************************

| This routine sets up the system DCBs in RAM using the information
| stored in ROM at address DCB_LST. This is called at initialization.
| CN_IVEC contains the name "DCB1" and IO_VEC the name "DCB2"

SET_DCB:
        MOVEM.L %a0-%a3/%d0-%d3,%a7@-      | Save all working registers
        LEA %a6@(FIRST),%a0               | Pointer to first DCB destination in RAM
        LEA %pc@(DCB_LST),%a1             | A1 points to DCB info block in ROM
        MOVE.W #5,%d0                   | 6 DCBs to set up
ST_DCB1:
        MOVE.W #15,%d1                  | 16 bytes to move per DCB header
ST_DCB2:
        MOVE.B %a1@+,%a0@+             | Move the 16 bytes of a DCB header
        DBRA %d1,ST_DCB2                | from ROM to RAM
        MOVE.W %a1@+,%d3                | Get size of parameter block (bytes)
        MOVE.W %d3,%a0@                 | Store size in DCB in RAM
        LEA %a0@(2,%d3:W),%a0              | A0 points to tail of DCB in RAM
        LEA %a0@(4),%a3                   | A3 contains address of next DCB in RAM
        MOVE.L %a3,%a0@                 | Store pointer to next DCB in this DCB
        LEA %a3@,%a0                    | A0 now points at next DCB in RAM
        DBRA %d0,ST_DCB1                | Repeat until all DCBs set up
        LEA %a3@(-4),%a3                  | Adjust A3 to point to last DCB pointer
        CLR.L %a3@                     | and force last pointer to zero
        MOVE.L #DCB1,%a6@(CN_IVEC)       | Set up vector to console input DCB
        MOVE.L #DCB2,%a6@(CN_OVEC)       | Set up vector to console output DCB
        MOVEM.L %a7@+,%a0-%a3/%d0-%d3      | Restore registers
        RTS

| ***************************************************************************

| IO_REQ handles all input/output transactions A0 points to DCB on
| entry. IO_REQ calls the device driver whose address is in the DCB.

IO_REQ:
        MOVEM.L %a0-%a1,%a7@-            | Save working registers
        LEA %a0@(8),%a1                   | A1 points to device handler field in DCB
        MOVE.L %a1@,%a1                 | A1 contains device handler address
        JSR %a1@                       | Call device handler
        MOVEM.L %a7@+,%a0-%a1            | Restore working registers
        RTS

| ***************************************************************************

| CON_IN handles input from the console device
| This is the device driver used by DCB1. Exit with input in D0

CON_IN:
        movem.l %d1/%a1,%a7@-           | save working registers
        lea     %a0@(12),%a1            | get pointer to COM port from DCB
        move.l  %a1@,%a1                | get address of COM port in A1
        clr.b   %a0@(19)                | clear logical error in DCB
CON_I1:
        move.b  %a1@(comRegLSR),%d1     | read COM port status
        btst    #0,%d1                  | test Data Ready bit
        beq     CON_I1                  | repeat until Data Ready bit set
        move.b  %d1,%a0@(18)            | store status bit in DCB
        and.b   #0b10001110,%d1         | mask to highlight error bits
        beq.s   CON_I2                  | if no error then skip update
        move.b  #1,%a0@(19)             | else update logical error
CON_I2:
        move.b  %a1@(comRegRX),%d0      | read input from COM port
        movem.l %a7@+,%a1/%d1           | restore working registers
        rts

| Original MC6850 ACIA data Rx function:
|CON_IN:
|        MOVEM.L %d1/%a1,%a7@-           | Save working registers
|        LEA     %a0@(12),%a1            | Get pointer to ACIA from DCB
|        MOVE.L  %a1@,%a1                | Get address of ACIA in A1
|        CLR.B   %a0@(19)                | Clear logical error in DCB
|CON_I1:
|        MOVE.B  %a1@,%d1                | Read ACIA status
|        BTST    #0,%d1                  | Test RDRF
|        BEQ     CON_I1                  | Repeat until RDRF true
|        MOVE.B  %d1,%a0@(18)            | Store physical status in DCB
|       AND.B   #0b011110100,%d1        | Mask to input error bits
|        BEQ.S   CON_I2                  | If no error then skip update
|        MOVE.B  #1,%a0@(19)             | Else update logical error
|CON_I2:
|        MOVE.B  %a1@(aciaDatOffset),%d0 | Read input from ACIA
|        MOVEM.L %a7@+,%a1/%d1           | Restore working registers
|        RTS

| ***************************************************************************

| This is the device driver used by DCB2. Output in D0
| The output can be halted or suspended

CON_OUT:
        movem.l %a1/%d1-%d2,%a7@-       | save working registers
        lea     %a0@(12),%a1            | get poitner to COM port from DCB
        move.l  %a1@,%a1                | get address of COM port in A1
        clr.b   %a0@(19)                | clear logical error in DCB
CON_OT1:
        move.b  %a1@(comRegLSR),%d1     | read COM port status
        btst    #0,%d1                  | test Data Ready bit (any input?)
        beq.s   CON_OT3                 | if no input then test output status
        move.b  %a1@(comRegRX),%d2      | else read the input
        and.b   #0b01011111,%d2         | strip parity and bit 5
        cmp.b   #WAIT,%d2               | and test for a wait condition
        bne.s   CON_OT3                 | if not wait, then ignore & test O/P
CON_OT2:
        move.b  %a1@(comRegLSR),%d2     | else read COM port status register
        btst    #0,%d2                  | and poll COM port until next char Rx
        beq     CON_OT2
CON_OT3:
        btst    #5,%d1                  | check if COM port ready for TX
        beq     CON_OT1                 | repeat until ready for TX
        move.b  %d1,%a0@(18)            | store status in DCB physical error
        move.b  %d0,%a1@(comRegTX)      | transmit byte
        movem.l %a7@+,%a1/%d1-%d2       | restore working registers
        rts

| Original MC8650 ACIA data Tx function:
|CON_OUT:
|        MOVEM.L %a1/%d1-%d2,%a7@-       | Save working registers
|        LEA     %a0@(12),%a1            | Get pointer to ACIA from DCB
|        MOVE.L  %a1@,%a1                | Get address of ACIA in A1
|        CLR.B   %a0@(19)                | Clear logical error in DCB
|CON_OT1:
|        MOVE.B  %a1@,%d1                | Read ACIA status
|        BTST    #0,%d1                  | Test RDRF bit (any input?)
|        BEQ.S   CON_OT3                 | If no input then test output status
|        MOVE.B  %a1@(aciaDatOffset),%d2 | else read the input
|        AND.B   #0b01011111,%d2         | Strip parity and bit 5
|        CMP.B   #WAIT,%d2               | and test for a wait condition
|        BNE.S   CON_OT3                 | If not wait then ignore and test O/P
|CON_OT2:
|        MOVE.B  %a1@,%d2                | Else read ACIA staus register
|        BTST    #0,%d2                  | and poll ACIA until next char received
|        BEQ     CON_OT2
|CON_OT3:
|        BTST    #1,%d1                  | Repeat
|        BEQ     CON_OT1                 | until ACIA Tx ready
|        MOVE.B  %d1,%a0@(18)            | Store status in DCB physical error
|        MOVE.B  %d0,%a1@(aciaDatOffset) | Transmit output
|        MOVEM.L %a7@+,%a1/%d1-%d2       | Restore working registers
|        RTS

| ***************************************************************************

| AUX_IN and AUX_OUT are simplified versions of CON_IN and
| CON_OUT for use with the port to the host processor

AUX_IN:
        lea     %a0@(12),%a1            | get pointer to aux COM port from DCB
        move.l  %a1@,%a1                | get address of aux COM port
AUX_IN1:
        btst    #0,%a1@(comRegLSR)      | test for data ready
        beq     AUX_IN1                 | repeat until ready
        move.b  %a1@(comRegRX),%d0      | read input 
        rts

AUX_OUT:
        lea     %a0@(12),%a1            | get pointer to aux COM port from DCB
        move.l  %a1@,%a1                | get address of aux COM port
AUX_OT1:
        btst    #5,%a1@                 | test for ready to transmit
        beq     AUX_OT1                 | repeat until TX ready
        move.b  %d0,%a1@(comRegTX)      | transmit data
        rts

| original MC6850 functions

|AUX_IN:
|        LEA %a0@(12),%a1                  | Get pointer to aux ACIA from DCB
|        MOVE.L %a1@,%a1                 | Get address of aux ACIA
|AUX_IN1:
|        BTST #0,%a1@                   | Test for data ready
|        BEQ AUX_IN1                    | Repeat until ready
|        MOVE.B %a1@(aciaDatOffset),%d0    | Read input
|        RTS

|AUX_OUT:
|        LEA %a0@(12),%a1                  | Get pointer to aux ACIA from DCB
|        MOVE.L %a1@,%a1                 | Get address of aux ACIA
|AUX_OT1:
|        BTST #1,%a1@                   | Test for ready to transmit
|        BEQ AUX_OT1                    | Repeat until transmitter ready
|        MOVE.B %d0,%a1@(aciaDatOffset)    | Transmit data
|        RTS

| ***************************************************************************

| GETCHAR gets a character from the console device
| This is the main input routine and uses the device whose name
| is stored in CN_IVEC. Changing this name redirects input.

GETCHAR:
        MOVE.L  %a0,%a7@-               | Save working register
        MOVE.L  %a6@(CN_IVEC),%a0       | A0 points to name of console DCB
        BSR     IO_OPEN                 | Open console (get DCB address in A0)
        BTST    #3,%d7                  | D7(3) set if open error
        BNE.S   GETCH3                  | If error then exit now
        BSR     IO_REQ                  | Else execute I/O transaction
        AND.B   #0x7F,%d0               | Strip msb of input
        TST.B   %a6@(U_CASE)            | Test for upper -> lower case conversion
        BNE.S   GETCH2                  | If flag not zero,do not convert case
        BTST    #6,%d0                  | Test input for lower case
        BEQ.S   GETCH2                  | If upper case then skip conversion
        AND.B   #0b11011111,%d0         | Else clear bit 5 for upper case conversion
GETCH2:
        TST.B   %a6@(ECHO)              | Do we need to echo the input?
        BNE.S   GETCH3                  | If ECHO not zero then no echo
        BSR     PUTCHAR                 | Else echo the input
GETCH3:
        MOVE.L  %a7@+,%a0               | Restore working register
        RTS                             | and return

| ***************************************************************************

| PUTCHAR sends a character to the console device
| The name of the output device is in CN_OVEC

PUTCHAR:
        MOVE.L %a0,%a7@-                | Save working register
        MOVE.L %a6@(CN_OVEC),%a0          | A0 points to name of console output
        BSR.S IO_OPEN                  | Open console (Get address of DCB)
        BSR IO_REQ                     | Perform output with DCB pointed at by A0
        MOVE.L %a7@+,%a0                | Restore working register
        RTS

| ***************************************************************************

| BUFF_IN and BUFF_OUT are two rudimentary input and output routines
| which input data from and output data to a buffer in RAM. These are
| used by DCB5 and DCB6,respectively

BUFF_IN:
        LEA %a0@(12),%a1                  | A1 points to I/P buffer
        MOVE.L %a1@,%a2                 | A2 gets I/P pointer from buffer
        MOVE.B %a2@-,%d0                | Read char from buffer and adjust A2
        MOVE.L %a2,%a1@                 | Restore pointer in buffer
        RTS

BUFF_OT:
        LEA %a0@(12),%a1                  | A1 points to O/P buffer
        MOVE.L %a1@(4),%a2                | A2 gets O/P pointer from buffer
        MOVE.B %d0,%a2@+                | Store char in buffer and adjust A2
        MOVE.L %a2,%a1@                 | Restore pointer in buffer
        RTS

| ***************************************************************************

| Open - opens a DCB for input or output. IO_OPEN converts the
| name pointed at by A0 into the address of the DCB pointed at
| by A0. Bit 3 of %d7 is set to zero if DCB not found

IO_OPEN:
        MOVEM.L %a1-%a3/%d0-%d4,%a7@-      | Save working registers
        LEA %a6@(FIRST),%a1               | A1 points to first DCB in chain in RAM
OPEN1:
        LEA %a1@,%a2                    | A2 = temp copy of pointer in DCB
        LEA %a0@,%a3                    | A3 = temp copy of pointer to DCB name
        MOVE.W #7,%d0                   | Up to 8 chars of DCB name to match
OPEN2:
        MOVE.B %a2@+,%d4                | Compare DCB name with string
        CMP.B %a3@+,%d4
        BNE.S OPEN3                    | If no match try next DCB
        DBRA %d0,OPEN2                  | Else repeat until all chars matched
        LEA %a1@,%a0                    | Success - move this DCB address to A0
        BRA.S OPEN4                    | and return
OPEN3:                                 | Fail - calculate address of next DCB
        MOVE.W %a1@(16),%d1               | Get parameter block size of DCB
        LEA %a1@(18,%d1:W),%a1             | A1 points to pointer to next DCB
        MOVE.L %a1@,%a1                 | A1 now points to next DCB <-- EVERYTHING FAILS WITHOUT THIS HERE!
        CMP.L #0,%a1                    | Test for end of DCB chain
        BNE OPEN1                      | If not end of chain then try next DCB
        OR.B #8,%d7                     | Else set error flag and return
OPEN4:
        MOVEM.L %a7@+,%a1-%a3/%d0-%d4      | Restore working registers
        RTS

| ***************************************************************************

| Exception vector table initialization routine
| All vectors not setup are loaded with uninitialized routine vector

X_SET:
        LEA X_BASE,%a0                  | Point to base of exception table
        MOVE.W #253,%d0                 | Number of vectors - 3
X_SET1:
        MOVE.L #X_UN,%a0@+             | Store uninitialized exception vector
        DBRA %d0,X_SET1                 | Repeat until all entries preset
        SUB.L %a0,%a0                    | Clear A0 (points to vector table)
        MOVE.L #BUS_ER,%a0@(8)           | Setup bus error vector
        MOVE.L #ADD_ER,%a0@(12)          | Setup address error vector
        MOVE.L #IL_ER,%a0@(16)           | Setup illegal instruction error vector
        MOVE.L #TRACE,%a0@(36)           | Setup trace exception vector
        MOVE.L #TRAP_0,%a0@(128)         | Setup TRAP #00 exception vector
        MOVE.L #BRKPT,%a0@(184)          | Setup TRAP #14 vector = breakpoint
        MOVE.L #WARM,%a0@(188)           | Setup TRAP #15 exception vector
        MOVE.W #7,%d0                   | Now clear the breakpoint table
        LEA %a6@(BP_TAB),%a0              | Point to table
X_SET2:
        CLR.L %a0@+                    | Clear an address entry
        CLR.W %a0@+                    | Clear the corresponding data
        DBRA %d0,X_SET2                 | Repeat until all 8 cleared
        RTS

| ***************************************************************************

TRAP_0:                                | User links to TS2BUG via TRAP #0
        CMP.B #0,%d1                    | %d1 = 0 = Get character
        BNE.S TRAP1
        BSR GETCHAR
        RTE
TRAP1:
        CMP.B #1,%d1                    | %d1 = 1 = Print character
        BNE.S TRAP2
        BSR PUTCHAR
        RTE
TRAP2:
        CMP.B #2,%d1                    | %d1 = 2 = Newline
        BNE.S TRAP3
        BSR NEWLINE
        RTE
TRAP3:
        CMP.B #3,%d1                    | %d1 = 3 = Get parameter from buffer
        BNE.S TRAP4
        BSR PARAM
        RTE
TRAP4:
        CMP.B #4,%d1                    | %d1 = 4 = Print string pointed at by A4
        BNE.S TRAP5
        BSR PSTRING
        RTE
TRAP5:
        CMP.B #5,%d1                    | %d1 = 5 = Get a hex character
        BNE.S TRAP6
        BSR HEX
        RTE
TRAP6:
        CMP.B #6,%d1                    | %d1 = 6 = Get a hex byte
        BNE.S TRAP7
        BSR BYTE
        RTE
TRAP7:
        CMP.B #7,%d1                    | %d1 = 7 = Get a word
        BNE.S TRAP8
        BSR WORD
        RTE
TRAP8:
        CMP.B #8,%d1                    | %d1 = 8 = Get a longword
        BNE.S TRAP9
        BSR LONGWD
        RTE
TRAP9:
        CMP.B #9,%d1                    | %d1 = 9 = Output hex byte
        BNE.S TRAP10
        BSR OUT2X
        RTE
TRAP10:
        CMP.B #10,%d1                   | %d1 = 10 = Output hex word
        BNE.S TRAP11
        BSR OUT4X
        RTE
TRAP11:
        CMP.B #11,%d1                   | %d1 = 11 = Output hex longword
        BNE.S TRAP12
        BSR OUT8X
        RTE
TRAP12:
        CMP.B #12,%d1                   | %d1 = 12 = Print a space
        BNE.S TRAP13
        BSR PSPACE
        RTE
TRAP13:
        CMP.B #13,%d1                   | %d1 = 13 = Get a line of text into
        BNE.S TRAP14                   | the line buffer
        BSR GETLINE
        RTE
TRAP14:
        CMP.B #14,%d1                   | %d1 = 14 = Tidy up the line in the
        BNE.S TRAP15                   | line buffer by removing leading
        BSR TIDY                       | leading and multiple embedded spaces
        RTE
TRAP15:
        CMP.B #15,%d1                   | %d1 = 15 = Execute the command in
        BNE.S TRAP16                   | the line buffer
        BSR EXECUTE
        RTE
TRAP16:
        CMP.B #16,%d1                   | %d1 = 16 = Call RESTORE to transfer
        BNE.S TRAP17                   | the registers in TSK_T to the 68000
        BSR RESTORE                    | and therefore execute a program
        RTE
TRAP17:
        RTE

| ***************************************************************************

| Display exception frame (D0 - %d7,%a0 - %a6,USP,SSP,SR,PC)
| EX_DIS prints registers saved after a breakpoint or exception
| The registers are saved in TSK_T

EX_DIS: 
        LEA %a6@(TSK_T),%a5               | A5 points to display frame
        LEA %pc@(MES3),%a4                | Point to heading
        BSR HEADING                    | and print it
        MOVE.W #7,%d6                   | 8 pairs of registers to display
        CLR.B %d5                       | %d5 is the line counter
EX_D1:
        MOVE.B %d5,%d0                   | Put current register number in D0
        BSR OUT1X                      | and print it
        BSR PSPACE                     | and a space
        ADD.B #1,%d5                    | Update counter for next pair
        MOVE.L %a5@,%d0                 | Get data register to be displayed
        BSR OUT8X                      | from the frame and print it
        LEA %pc@(MES4),%a4                | Print string of spaces
        BSR.L PSTRING                  | between data and address registers
        MOVE.L %a5@(32),%d0               | Get address register to be displayed
        BSR OUT8X                      | which is 32 bytes on from data reg
        BSR NEWLINE
        LEA %a5@(4),%a5                   | Point to next pair (ie Di,Ai)
        DBRA %d6,EX_D1                  | Repeat until all displayed
        LEA %a5@(32),%a5                  | Adjust pointer by 8 longwords
        BSR NEWLINE                    | to point to SSP
        LEA %pc@(MES2A),%a4               | Point to "SS = "
        BSR PSTRING                    | Print it
        MOVE.L %a5@+,%d0                | Get SSP from frame
        BSR OUT8X                      | and display it
        BSR NEWLINE
        LEA %pc@(MES1),%a4                | Point to "SR = "
        BSR PSTRING                    | Print it
        MOVE.W %a5@+,%d0                | Get status register
        BSR OUT4X                      | Display status
        BSR NEWLINE
        LEA %pc@(MES2),%a4                | Point to "PC = "
        BSR PSTRING                    | Print it
        MOVE.L %a5@+,%d0                | Get PC
        BSR OUT8X                      | Display PC
        BRA NEWLINE                    | Newline and return

| ***************************************************************************

| Exception handling routines

IL_ER:                                 | Illegal instruction exception
        MOVE.L %a4,%a7@-                | Save A4
        LEA %pc@(MES10),%a4               | Point to heading
        BSR HEADING                    | Print it
        MOVE.L %a7@+,%a4                | Restore A4
        BSR.S GROUP2                   | Save registers in display frame
        BSR EX_DIS                     | Display registers saved in frame
        BRA WARM                       | Abort from illegal instruction

BUS_ER:                                | Bus error (group 1) exception
        MOVE.L %a4,%a7@-                | Save A4
        LEA %pc@(MES8),%a4                | Point to heading
        BSR HEADING                    | Print it
        MOVE.L %a7@+,%a4                | Restore A4
        BRA.S GROUP1                   | Deal with group 1 exception

ADD_ER:                                | Address error (group 1) exception
        MOVE.L %a4,%a7@-                | Save A4
        LEA %pc@(MES9),%a4                | Point to heading
        BSR HEADING                    | Print it
        MOVE.L %a7@+,%a4                | Restore A4
        BRA.S GROUP1                   | Deal with group 1 exception

BRKPT:                                 | Deal with breakpoint
        MOVEM.L %d0-%d7/%a0-%a6,%a7@-      | Save all registers
        BSR BR_CLR                     | Clear breakpoints in code
        MOVEM.L %a7@+,%d0-%d7/%a0-%a6      | Restore registers
        BSR.S GROUP2                   | Treat as group 2 exception
        LEA %pc@(MES11),%a4               | Point to heading
        BSR HEADING                    | Print it
        BSR EX_DIS                     | Display saved registers
        BRA WARM                       | Return to monitor

| ***************************************************************************

| GROUP1 is called by address and bus error exceptions
| These are "turned into group 2" exceptions (eg TRAP)
| by modifying the stack frame saved by a group 1 exception

GROUP1:
        MOVEM.L %d0/%a0,%a7@-            | Save working registers
        MOVE.L %a7@(18),%a0               | Get PC from group 1 stack frame
        MOVE.W %a7@(14),%d0               | Get instruction from stack frame
        CMP.W %a0@-,%d0                 | Now backtrack to find the "correct PC"
        BEQ.S GROUP1A                  | by matching the op-code on the stack
        CMP.W %a0@-,%d0                 | with the code in the region of the
        BEQ.S GROUP1A                  | PC on the stack
        CMP.W %a0@-,%d0
        BEQ.S GROUP1A
        CMP.W %a0@-,%d0
        BEQ.S GROUP1A
        SUBQ.L #2,%a0
GROUP1A:
        MOVE.L %a0,%a7@(18)               | Restore modified PC to stack frame
        MOVEM.L %a7@+,%d0/%a0            | Restore working registers
        LEA %a7@(8),%a7                   | Adjust stack pointer to group 1 type
        BSR.S GROUP2                   | Now treat as group 1 exception
        BSR EX_DIS                     | Display contents of exception frame
        BRA WARM                       | Exit to monitor - no RTE from group 2

GROUP2:                                | Deal with group 2 exceptions
        MOVEM.L %a0-%a7/%d0-%d7,%a7@-      | Save all registers on the stack
        MOVE.W #14,%d0                  | Transfer %d0-%d7,%a0-%a6 from
        LEA %a6@(TSK_T),%a0               | the stack to the display frame
GROUP2A:
        MOVE.L %a7@+,%a0@+             | Move a register from stack to frame
        DBRA %d0,GROUP2A                | and repeat until %d0-%d7/%a0-%a6 moved
        MOVE.L %usp,%a2                  | Get the user stack pointer and put it
        MOVE.L %a2,%a0@+                | in the A7 position in the frame
        MOVE.L %a7@+,%d0                | Now transfer the SSP to the frame
        SUB.L #10,%d0                   | remembering to account for the
        MOVE.L %d0,%a0@+                | data pushed on the stack to this point
        MOVE.L %a7@+,%a1                | Copy TOS (return address) to A1
        MOVE.W %a7@+,%a0@+             | Move SR to display frame
        MOVE.L %a7@+,%d0                | Get PC in D0
        SUBQ.L #2,%d0                   | Move back to current instruction
        MOVE.L %d0,%a0@+                | Put adjusted PC in display frame
        JMP %a1@                       | Return from subroutine

| ***************************************************************************

| GO executes a program either from a supplied address or
| by using the data in the display frame

GO:
        BSR PARAM                      | Get entry address (if any)
        TST.B %d7                       | Test for error in input
        BEQ.S GO1                      | If %d7 zero then OK
        LEA %pc@(ERMES1),%a4              | Else point to error message
        BRA PSTRING                    | print it and return
GO1:
        TST.L %d0                       | If no address entered then get
        BEQ.S GO2                      | address from display frame
        MOVE.L %d0,%a6@(TSK_T+70)         | Else save address in display frame
        MOVE.W #0x2700,%a6@(TSK_T+68)     | Store dummy status in frame
GO2:
        BRA.S RESTORE                  | Restore volatile environment and go

GB:
        BSR BR_SET                     | Same as go but presets breakpoints
        BRA.S GO                       | Execute program

| ***************************************************************************

| RESTORE moves the volatile environment from the display
| frame and transfers it to the 68000s registers. This
| re-runs a program suspended after an exception

RESTORE:
        LEA %a6@(TSK_T),%a3               | A3 points to display frame
        LEA %a3@(74),%a3                  | A3 now points to end of frame + 4
        LEA %a7@(4),%a7                   | Remove return address from stack
        MOVE.W #36,%d0                  | Counter for 37 words to be moved
REST1:
        MOVE.W %a3@-,%a7@-             | Move word from display frame to stack
        DBRA %d0,REST1                  | Repeat until entire frame moved
        MOVEM.L %a7@+,%d0-%d7            | Restore old data registers from stack
        MOVEM.L %a7@+,%a0-%a6            | Restore old address registers
        LEA %a7@(8),%a7                   | Except SSP/USP - so adjust stack
        RTE                            | Return from exception to run program

TRACE:                                 | TRACE exception (rudimentary version)
        MOVE.L %pc@(MES12),%a4            | Point to heading
        BSR HEADING                    | Print it
        BSR GROUP1                     | Save volatile environment
        BSR EX_DIS                     | Display it
        BRA WARM                       | Return to monitor

| ***************************************************************************

| Breakpoint routines: BR_GET gets the address of a breakpoint and
| puts it in the breakpoint table. It does not plant it in the code.
| BR_SET plants all breakpoints in the code. NOBR removes one or all
| breakpoints from the table. KILL removes breakpoints from the code.

BR_GET:
        BSR PARAM                      | Get breakpoint address in table
        TST.B %d7                       | Test for input error
        BEQ.S BR_GET1                  | If no error then continue
        LEA %pc@(ERMES1),%a4              | Else display error
        BRA PSTRING                    | and return
BR_GET1:
        LEA %a6@(BP_TAB),%a3              | A6 points to breakpoint table
        MOVE.L %d0,%a5                   | Save new BP address in A5
        MOVE.L %d0,%d6                   | and in %d6 because %d0 gets corrupted
        MOVE.W #7,%d5                   | Eight entries to test
BR_GET2:
        MOVE.L %a3@+,%d0                | Read entry from breakpoint table
        BNE.S BR_GET3                  | If not zero display existing BP
        TST.L %d6                       | Only store a non-zero breakpoint
        BEQ.S BR_GET4
        MOVE.L %a5,%a3@(-4)               | Store new breakpoint in table
        MOVE.W %a5@,%a3@               | Save code at BP address in table
        CLR.L %d6                       | Clear %d6 to avoid repetition
BR_GET3:
        BSR OUT8X                      | Display this breakpoint
        BSR NEWLINE
BR_GET4:
        LEA %a3@(2),%a3                   | Step past stored op-code
        DBRA %d5,BR_GET2                | Repeat until all entries tested
        RTS                            | Return

BR_SET:                                | Plant any breakpoints in user code
        LEA %a6@(BP_TAB),%a0              | A0 points to BP table
        LEA %a6@(TSK_T+70),%a2            | A2 points to PC in display frame
        MOVE.L %a2@,%a2                 | Now A2 contains value of PC
        MOVE.W #7,%d0                   | Up to eight entries to plant
BR_SET1:
        MOVE.L %a0@+,%d1                | Read breakpoint address from table
        BEQ.S BR_SET2                  | If zero then skip planting
        CMP.L %a2,%d1                    | Dont want to plant BP at current PC
        BEQ.S BR_SET2                  | location,so skip planting if same
        MOVE.L %d1,%a1                   | Transfer BP address to address reg
        MOVE.W #TRAP_14,%a1@           | Plant op-code for TRAP #14 in code
BR_SET2:
        LEA %a0@(2),%a0                   | Skip past op-code field in table
        DBRA %d0,BR_SET1                | Repeat until all entries tested
        RTS

NOBR:                                  | Clear one or all breakpoints
        BSR PARAM                      | Get BP address (if any)
        TST.B %d7                       | Test for input error
        BEQ.S NOBR1                    | If no error then skip abort
        LEA %pc@(ERMES1),%a4              | Point to error message
        BRA PSTRING                    | Display it and return
NOBR1:
        TST.L %d0                       | Test for null address (clear all)
        BEQ.S NOBR4                    | If no address then clear all entries
        MOVE.L %d0,%a1                   | Else just clear breakpoint in A1
        LEA %a6@(BP_TAB),%a0              | A0 points to BP table
        MOVE.W #7,%d0                   | Up to eight entries to test
NOBR2:
        MOVE.L %a0@+,%d1                | Get entry and
        LEA %a0@(2),%a0                   | skip past op-code field
        CMP.L %a1,%d1                    | Is this the one?
        BEQ.S NOBR3                    | If so go and clear entry
        DBRA %d0,NOBR2                  | Repeat until all tested
        RTS
NOBR3:
        CLR.L %a0@(-6)                   | Clear address in BP table
        RTS
NOBR4:
        LEA %a6@(BP_TAB),%a0              | Clear all 8 entries in BP table
        MOVE.W #7,%d0                   | Eight entries to clear
NOBR5:
        CLR.L %a0@+                    | Clear breakpoint address
        CLR.W %a0@+                    | Clear op-code field
        DBRA %d0,NOBR5                  | Repeat until all done
        RTS

BR_CLR:                                | Remove breakpoints from code
        LEA %a6@(BP_TAB),%a0              | A0 points to breakpoint table
        MOVE.W #7,%d0                   | Up to eight entries to clear
BR_CLR1:
        MOVE.L %a0@+,%d1                | Get address of BP in D1
        MOVE.L %d1,%a1                   | and put copy in A1
        TST.L %d1                       | Test this breakpoint
        BEQ.S BR_CLR2                  | If zero then skip BP clearing
        MOVE.W %a0@,%a1@               | Else restore op-code
BR_CLR2:
        LEA %a0@(2),%a0                   | Skip past op-code field
        DBRA %d0,BR_CLR1                | Repeat until all tested
        RTS

| ***************************************************************************

| REG_MOD modifies a register in the display frame. The command
| format is REG <reg> <value>. E.g. REG %d3 1200

REG_MOD:
        CLR.L %d1                       | %d1 to hold name of register
        LEA %a6@(BUFFPT),%a0              | A0 contains address of buffer pointer
        MOVE.L %a0@,%a0                 | A0 now points to next char in buffer
        MOVE.B %a0@+,%d1                | Put first char of name in D1
        ROL.W #8,%d1                    | Move char one place left
        MOVE.B %a0@+,%d1                | Get second char in D1
        LEA %a0@(1),%a0                   | Move pointer past space in buffer
        MOVE.L %a0,%a6@(BUFFPT)           | Update buffer pointer
        CLR.L %d2                       | %d2 is the character pair counter
        LEA %pc@(REGNAME),%a0             | A0 points to string of character pairs
        LEA %a0@,%a1                    | A1 also points to string
REG_MD1:
        CMP.W %a0@+,%d1                 | Compare a char pair with input
        BEQ.S REG_MD2                  | If match then exit loop
        ADD.L #1,%d2                    | Else increment match counter
        CMP.L #19,%d2                   | Test for end of loop
        BNE REG_MD1                    | Continue until all pairs matched
        LEA %pc@(ERMES1),%a4              | If here then error
        BRA PSTRING                    | Display error and return
REG_MD2:
        LEA %a6@(TSK_T),%a1               | A1 points to display frame
        ASL.L #2,%d2                    | Multiply offset by 4 (4 bytes/entry)
        CMP.L #72,%d2                   | Test for address of PC
        BNE.S REG_MD3                  | If not PC then all is OK
        SUB.L #2,%d2                    | else dec PC pointer as Sr is a word
REG_MD3:
        LEA %a1@(%d2.l),%a2             | Calculate address of entry in disptable
        MOVE.L %a2@,%d0                 | Get old contents
        BSR OUT8X                      | Display them
        BSR NEWLINE
        BSR PARAM                      | Get new data
        TST.B %d7                       | Test for input error
        BEQ.S REG_MD4                  | If no error then go and store data
        LEA %pc@(ERMES1),%a4              | Else point to error message
        BRA PSTRING                    | print it and return
REG_MD4:
        CMP.L #68,%d2                   | If this address is the SR then
        BEQ.S REG_MD5                  | we have only a word to store
        MOVE.L %d0,%a2@                 | Else store new data in display frame
        RTS
REG_MD5:
        MOVE.W %d0,%a2@                 | Store SR (one word)
        RTS

| ***************************************************************************

X_UN:                                       | Uninitialized exception vector routine
        bsr     EX_DIS                      | display register before we change any
        LEA     %pc@(ERMES6),%a4            | Point to error message
        BSR     PSTRING                     | Display it
        | get the exception number from the stack frame
        | then load the string with the name of that exception
        eor.l   %d0,%d0                     | clear D0
        move.w  %sp@(6),%d0                 | get vector offset from stack frame
        andi.w  #0x0fff,%d0                 | mask off frame type from offset
        lea     tblVecStr,%a4               | get string pointer table address
        add.l   %d0,%a4                     | add vector offset to pointer
        move.l  %a4@,%a4                    | get string pointer
        bsr     PSTRING                     | print exception string

|        BSR     EX_DIS                      | Display registers
        BRA     WARM                        | Abort

| ***************************************************************************

| All strings and other fixed parameters here

BANNER:
        .ascii "TSBUG 2 Version 23.07.86\0\0"
CRLF:
        .ascii "\r\n?\0"                | CR,LF,'?',0
HEADER:
        .ascii "\r\nS1\0\0"             | CR,LF,'S','1',0,0
TAIL:
        .ascii "S9 \0\0"
MES1:
        .ascii " SR = \0"
MES2:
        .ascii " PC = \0"
MES2A:
        .ascii " SS = \0"
MES3:
        .ascii " Data reg Address reg\0\0"
MES4:
        .ascii " \0\0"
MES8:
        .ascii "Bus error \0\0"
MES9:
        .ascii "Address error \0\0"
MES10:
        .ascii "Illegal instruction \0\0"
MES11:
        .ascii "Breakpoint \0\0"
MES12:
        .ascii "Trace \0"
REGNAME:
        .ascii "D0D1D2D3D4D5D6D7"
        .ascii "A0A1A2A3A4A5A6A7"
        .ascii "SSSR"
        .ascii "PC \0"
ERMES1:
        .ascii "Non-valid hexadecimal input \0"
ERMES2:
        .ascii "Invalid command \0"
ERMES3:
        .ascii "Loading error\0"
ERMES4:
        .ascii "Table full \0\0"
ERMES5:
        .ascii "Breakpoint not active \0\0"
ERMES6:
        .ascii "Uninitialized exception \0\0"
ERMES7:
        .ascii " Range error\0"

| ***************************************************************************

| COMTAB    is the built-in command table. All entries are made up of
| a string length + number of characters to match + the string
| plus the address of the command relative to COMTAB

COMTAB:
        DC.B 4,4                       | JUMP <address> causes execution to
        .ascii "JUMP"                    | begin at <address>
        DC.L JUMP-COMTAB               | n
        DC.B 8,3                       | MEMORY <address> examines contents of
        .ascii "MEMORY  "                 | <address> and allows them to be changed
        DC.L MEMORY-COMTAB
        DC.B 4,2                       | LOAD <string> loads S1/S2 records
        .ascii "LOAD"                    | from the host. <string> is sent to host
        DC.L LOAD-COMTAB
        DC.B 4,2                       | DUMP <string> sends S1 records to the
        .ascii "DUMP"                    | host and is preceded by <string>
        DC.L DUMP-COMTAB
        DC.B 4,3                       | TRAN enters the transparent mode
        .ascii "TRAN"                    | and is exited by ESC,E.
        DC.L TM-COMTAB
        DC.B 4,2                       | NOBR <address> removes the breakpoint
        .ascii "NOBR"                    | at <address> from the BP table. If
        DC.L NOBR-COMTAB               | no address is given all BPs are removed
        DC.B 4,2                       | DISP displays the contents of the
        .ascii "DISP"                    | pseudo registers in TSK_T.
        DC.L EX_DIS-COMTAB
        DC.B 4,2                       | GO <address> starts program execution
        .ascii "GO  "                     | at <address> and loads regs from TSK_T
        DC.L GO-COMTAB
        DC.B 4,2                       | BRGT puts a breakpoint in the BP
        .ascii "BRGT"                    | table - but not in the code
        DC.L BR_GET-COMTAB
        DC.B 4,2                       | PLAN puts the breakpoints in the code
        .ascii "PLAN"
        DC.L BR_SET-COMTAB
        DC.B 4,4                       | KILL removes breakpoints from the code
        .ascii "KILL"
        DC.L BR_CLR-COMTAB
        DC.B 4,2                       | GB <address> sets breakpoints and
        .ascii "GB  "                     | then calls GO.
        DC.L GB-COMTAB
        DC.B 4,3                       | REG <reg> <value> loads <value>
        .ascii "REG "                    | into <reg> in TASK_T. Used to preset
        DC.L REG_MOD-COMTAB            | registers before a GO or GB
        DC.B 0,0

| ***************************************************************************

| This is a list of the information needed to setup the DCBs

DCB_LST:
DCB1:
        .ascii  "CON_IN  "              | Device name (8 bytes)
        dc.l    CON_IN,spioCOM0         | Address of driver routine, device
        dc.w    2                       | Number of words in parameter field
DCB2:
        .ascii  "CON_OUT "
        dc.l    CON_OUT,spioCOM0
        dc.w    2
DCB3:
        .ascii  "AUX_IN  "
        dc.l    AUX_IN,spioCOM1
        dc.w    2
DCB4:
        .ascii  "AUX_OUT "
        dc.l    AUX_OUT,spioCOM1
        dc.w    2
DCB5:
        .ascii  "BUFF_IN "
        dc.l    BUFF_IN,BUFFER
        dc.w    2
DCB6:
        .ascii  "BUFF_OUT"
        dc.l    BUFF_OT,BUFFER
        dc.w    2

|DCB_LST:
|DCB1:
|        .ascii "CON_IN  "                 | Device name (8 bytes)
|        DC.L CON_IN,ACIA_1             | Address of driver routine,device
|        DC.W 2                         | Number of words in parameter field
|DCB2:
|        .ascii "CON_OUT "
|        DC.L CON_OUT,ACIA_1
|        DC.W 2
|DCB3:
|        .ascii "AUX_IN  "
|        DC.L AUX_IN,ACIA_2
|        DC.W 2
|DCB4:
|        .ascii "AUX_OUT "
|        DC.L AUX_OUT,ACIA_2
|        DC.W 2
|DCB5:
|        .ascii "BUFF_IN "
|        DC.L BUFF_IN,BUFFER
|        DC.W 2
|DCB6:
|        .ascii "BUFF_OUT"
|        DC.L BUFF_OT,BUFFER
|        DC.W 2

| ***************************************************************************

| DCB structure

|           -------------------------
| 0 ->      |DCB name               |
|           |-----------------------|
| 8 ->      |Device driver          |
|           |-----------------------|
| 12 ->     |Device address         |
|           |-----------------------|
| 16 ->     | Size of param block   |
|           |-----------------------| --
| 18 ->     |Status                 |     |
|           |  logical  | physical  |     | S
|           |-----------------------|     |
|                 .     .     .
|           |-----------------------| --
| 18+S ->   | Pointer to next DCB   |

| *****************************************************************************
| techav - 20230521
| expanding the uninitialized exception handler to be a little more helpful by
| giving a name to the exception that was encountered.

| start with the strings of all of the exception names
strVecGeneric:  .ascii  "Generic Interrupt\r\n\0"
strVecZeroDiv:  .ascii  "Divide by Zero\r\n\0"
strVecCHK:      .ascii  "CHK/CHK2 Instruction\r\n\0"
strVecTrapV:    .ascii  "TRAP Instruction\r\n\0"
strVecPriv:     .ascii  "Privilege Violation\r\n\0"
strVecTrace:    .ascii  "Trace\r\n\0"
strVecATrap:    .ascii  "$A-Line Instruction Trap\r\n\0"
strVecFTrap:    .ascii  "$F-Line Instruction Trap\r\n\0"
strVecCprcViol: .ascii  "Coprocessor Protocol Violation\r\n\0"
strVecFormat:   .ascii  "Format Error\r\n\0"
strVecUninit:   .ascii  "Uninitialized Interrupt\r\n\0"
strVecSpur:     .ascii  "Spurious Interrupt\r\n\0"
strVecInt1:     .ascii  "AVEC Level 1\r\n\0"
strVecInt2:     .ascii  "AVEC Level 2\r\n\0"
strVecInt3:     .ascii  "AVEC Level 3\r\n\0"
strVecInt4:     .ascii  "AVEC Level 4\r\n\0"
strVecInt5:     .ascii  "AVEC Level 5\r\n\0"
strVecInt6:     .ascii  "AVEC Level 6\r\n\0"
strVecInt7:     .ascii  "AVEC Level 7\r\n\0"
strVecTrap1:    .ascii  "Trap 0 Instruction\r\n\0"
strVecTrap2:    .ascii  "Trap 1 Instruction\r\n\0"
strVecTrap3:    .ascii  "Trap 3 Instruction\r\n\0"
strVecTrap4:    .ascii  "Trap 4 Instruction\r\n\0"
strVecTrap5:    .ascii  "Trap 5 Instruction\r\n\0"
strVecTrap6:    .ascii  "Trap 6 Instruction\r\n\0"
strVecTrap7:    .ascii  "Trap 7 Instruction\r\n\0"
strVecTrap8:    .ascii  "Trap 8 Instruction\r\n\0"
strVecTrap9:    .ascii  "Trap 9 Instruction\r\n\0"
strVecTrapA:    .ascii  "Trap 10 Instruction\r\n\0"
strVecTrapB:    .ascii  "Trap 11 Instruction\r\n\0"
strVecTrapC:    .ascii  "Trap 12 Instruction\r\n\0"
strVecTrapD:    .ascii  "Trap 13 Instruction\r\n\0"
strVecFPUunord: .ascii  "FPU Unordered Condition\r\n\0"
strVecFPUinxct: .ascii  "FPU Inexact Result\r\n\0"
strVecFPUdiv0:  .ascii  "FPU Divide by Zero\r\n\0"
strVecFPUunder: .ascii  "FPU Underflow\r\n\0"
strVecFPUopErr: .ascii  "FPU Operand Error\r\n\0"
strVecFPUover:  .ascii  "FPU Overflow\r\n\0"
strVecFPUnan:   .ascii  "FPU Not a Number\r\n\0"
strVecMMUcnfg:  .ascii  "MMU Configuration Error\r\n\0"
strVec68851:    .ascii  "MC68851 MMU Error\r\n\0"

| now build a table of the string pointers for each vector
tblVecStr:
    dc.l    strVecGeneric   | initial stack pointer
    dc.l    strVecGeneric   | initial program counter
    dc.l    strVecGeneric   | bus error
    dc.l    strVecGeneric   | address error
    dc.l    strVecGeneric   | illegal instruction
    dc.l    strVecZeroDiv   
    dc.l    strVecCHK
    dc.l    strVecTrapV
    dc.l    strVecPriv
    dc.l    strVecTrace
    dc.l    strVecATrap
    dc.l    strVecFTrap
    dc.l    strVecGeneric
    dc.l    strVecCprcViol
    dc.l    strVecFormat
    dc.l    strVecUninit
    dc.l    strVecGeneric
    dc.l    strVecGeneric
    dc.l    strVecGeneric
    dc.l    strVecGeneric
    dc.l    strVecGeneric
    dc.l    strVecGeneric
    dc.l    strVecGeneric
    dc.l    strVecGeneric
    dc.l    strVecSpur
    dc.l    strVecInt1
    dc.l    strVecInt2
    dc.l    strVecInt3
    dc.l    strVecInt4
    dc.l    strVecInt5
    dc.l    strVecInt6
    dc.l    strVecInt7
    dc.l    strVecGeneric   | Trap0 handled elsewhere
    dc.l    strVecTrap1
    dc.l    strVecTrap2
    dc.l    strVecTrap3
    dc.l    strVecTrap4
    dc.l    strVecTrap5
    dc.l    strVecTrap6
    dc.l    strVecTrap7
    dc.l    strVecTrap8
    dc.l    strVecTrap9
    dc.l    strVecTrapA
    dc.l    strVecTrapB
    dc.l    strVecTrapC
    dc.l    strVecTrapD
    dc.l    strVecGeneric   | Trap14 handled elsewhere
    dc.l    strVecGeneric   | Trap15 handled elsewhere
    dc.l    strVecFPUunord
    dc.l    strVecFPUinxct
    dc.l    strVecFPUdiv0
    dc.l    strVecFPUunder
    dc.l    strVecFPUopErr
    dc.l    strVecFPUover
    dc.l    strVecFPUnan
    dc.l    strVecGeneric
    dc.l    strVecMMUcnfg
    dc.l    strVec68851
    dc.l    strVec68851


    