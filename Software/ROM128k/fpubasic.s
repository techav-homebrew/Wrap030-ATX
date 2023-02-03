|************************************************************************************
| Enhanced BASIC for the Motorola MC680xx
|
| This version is for the TS2 single board computer
| Jeff Tranter (tranter@pobox.com)
|
|************************************************************************************
|
| Copyright(C) 2002-12 by Lee Davison. This program may be freely distributed
| for personal use only. All commercial rights are reserved.
| 
| More 68000 and other projects can be found on my website at ..
| http://mycorner.no-ip.org/index.html
| mail : leeedavison@googlemail.com
| 
|************************************************************************************
| 
| Modified 2022/01/31
| techav
| - converted syntax for GNU AS
| - modified startup to work with TSMON
| Modified 2022/10/08
| techav
| - added support for M68882 FPU
| Modified 2021/12/29
| techav
| - added some parameters to make it easier to run from an external loader
| Modified 2019/07/20
| techav
| - modified addresses for 68030 sbc
| Modified 2018/11/20
| techav
| - modified addresses for 68000 sbc
| - cleaned up formatting, tabs, etc. 

| uncomment to enable debugging messages
debug:

| Ver 3.52

| Ver 3.52 stops USING$() from reading beyond the end of the format string
| Ver 3.51 fixes the UCASE0x() and LCASE0x() functions for null strings
| Ver 3.50 unary minus in concatenate generates a type mismatch error
| Ver 3.49 doesnt tokenise 'DEF' or 'DEC' within a hex value
| Ver 3.48 allows scientific notation underflow in the USING$() function
| Ver 3.47 traps the use of array elements as the FOR loop variable
| Ver 3.46 updates function and function variable handling

|************************************************************************************
|
| Ver 3.45 makes the handling of non existant variables consistent and gives the
| option of not returning an error for a non existant variable. If this is the
| behaviour you want just change novar to some non zero value

    .equ novar,0                        | non-existant variables cause errors

|************************************************************************************

| Ver 3.44 adds overflow indication to the USING$() function
| Ver 3.43 removes an undocumented feature of concatenating null strings
| Ver 3.42 reimplements backspace so that characters are overwritten with [SPACE]
| Ver 3.41 removes undocumented features of the USING$() function
| Ver 3.40 adds the USING$() function
| Ver 3.33 adds the file requester to LOAD and SAVE
| Ver 3.32 adds the optional ELSE clause to IF .. THEN

|************************************************************************************
|
| Version 3.25 adds the option to change the behaviour of INPUT so that a null
| response does not cause a program break. If this is the behaviour you want just
| change nobrk to some non zero value.

    .equ nobrk,0                        | null response to INPUT causes a break

|************************************************************************************
|
| Version 3.xx replaces the fixed RAM addressing from previous versions with a RAM
| pointer in a3. this means that this could now be run as a task on a multitasking
| system where memory resources may change.

|************************************************************************************
    .include "macros.inc"
    .include "fpubasic.inc"


    .section text,"ax"

    .extern acia1Com
    .extern acia1Dat
    .extern acia2Com
    .extern acia2Dat
    .global startBasic
    .global labsizok
    .global labWARM
    .global flagFPU
    .global FAC1_m
    .global FAC1_e
    .global FAC2_m
    .global FAC2_e

    .equ    acia2offset,8
    .equ    aciaDatOffset,4


| This is the first instruction in this program. 
| Jumping to the base ROM address will start execution here, which immediately
| jumps to the initialization routine. 
    .even
    bra        startBasic

|************************************************************************************
| the following code is simulator specific, change to suit your system
| output character to the console from register d0.b

VEC_OUT:
    movem.l %a0/%d1,%a7@-               | Save working registers
    lea.l   acia1Com,%a0                | A0 points to console ACIA
TXNOTREADY:
    btst    #1,%a0@                     | check TDRE bit
    beq.s   TXNOTREADY                  | Until ACIA Tx ready
    move.b  %d0,%a0@(aciaDatOffset)     | Write character to send
    movem.l %a7@+,%a0/%d1               | Restore working registers
    rts

|************************************************************************************
| input a character from the console into register d0
| else return Cb=0 if there is no character available

| Modified to check the primary and secondary ACIA for input
VEC_IN:
    movem.l %a0,%a7@-                   | save working register
    lea     acia1Com,%a0                | get ACIA 1 pointer
    btst    #0,%a0@                     | read ACIA 1 status bit
    bne.s   RX1Ready                    | ACIA 1 has received data
    btst    #0,%a0@(acia2offset)        | read ACIA 2 status bit
    bne.s   RX2Ready                    | ACIA 2 has data
RXNOTREADY:
    movem.l %a7@+,%a0                   | restore working register
    andi.b  #0xFE,%ccr                  | clear carry flag - no chars available
    rts
RX1Ready:
    move.b  %a0@(aciaDatOffset),%d0     | read ACIA 1 received byte
    bra.s   RXDone                      | jump to exit
RX2Ready:
    move.b  %a0@(acia2offset+aciaDatOffset),%d0
RXDone:
    movem.l %a7@+,%a0                   | restore working register
    ori.b   #1,%ccr                     | set carry flag - char available
    rts

|************************************************************************************
|
| LOAD routine for the TS2 computer (not implemented)

VEC_LD:
    moveq    #0x2E,%d7    | error code 0x2E "Not implemented" error
    bra    labXERR    | do error #%d7, then warm start

|************************************************************************************
|
| SAVE routine for the TS2 computer (not implemented)

VEC_SV:
    moveq    #0x2E,%d7    | error code 0x2E "Not implemented" error
    bra    labXERR    | do error #%d7, then warm start

|************************************************************************************
    .even
| end of simulator specific code


|***************************************************************************************
|***************************************************************************************
|***************************************************************************************
|***************************************************************************************
|
| Register use :- (must improve this !!)
|
|    a6 -    temp Bpntr    | temporary BASIC execute pointer
|    a5 -    Bpntr    | BASIC execute (get byte) pointer
|    a4 -    des_sk    | descriptor stack pointer
|    a3 -    ram_strt    | start of RAM. all RAM references are offsets
|            | from this value
|

|************************************************************************************
| BASIC cold start entry point. assume entry with RAM address in a0 and RAM length
| in d0

startBasic:
labCOLD:
|    cmpi.l  #0x04000,%d0                | compare size with 16k
|    bge.s   labsizok                    | branch if >= 16k
|    lea     %pc@(basMemErr),%a4         | get pointer to memory error message
|    moveq   #4,%d1                      | TSMON PSTRING trap
|    trap    #0                          | call TSMON trap handler
|    rts                                 | return to monitor

|basMemErr:
|    .ascii  "Not enough free memory to run BASIC. Exiting.\r\n\0"
|    .even

labsizok:
|    movea.l %a0,%a3                     | copy RAM base to a3
    move.l  #0,%a3                      | pointer offsets provided by linker
                                        | relative to address $0000,0000.
    adda.l  %d0,%a0                     | a0 is top of RAM
    move.l  %a0,%a3@(Ememl)             | set end of mem
    lea     %a3@(ram_base),%sp          | set stack to RAM start + 1k


    | techav
    | inserting code to check for presence of FPU
    |    %a3@(flagFPU) = 0    : FPU exists & working
    |    %a3@(flagFPU) = 1    : FPU does not exist
    movem.l %a0-%a1,%sp@-               | save working registers
    move.l  #0x02C,%a0                  | get the F-trap vector address
    move.l  %a0@,%sp@-                  | save the current F-trap vector address
    lea     %pc@(vecFPUNO),%a1          | calculate the new F-trap vector
    move.l  %a1,%a0@                    | save the new F-trap vector
    clr.b   %a3@(flagFPU)               | clear FPU flag

    fnop                                | try to execute FPU NOP instruction

    move.l  %sp@+,%a0@                  | restore F-trap vector address
    movem.l %sp@+,%a0-%a1               | restore working registers
    bra     bootContinue
vecFPUNO:

    move.b  #1,%a3@(flagFPU)            | set no FPU flag
    add.l   #4,%sp@(2)                  | increment return pointer
    rte                                 | return from exception
bootContinue:
    | end of FPU check code


    move.w  #0x4EF9,%d0                 | jmp opcode
    movea.l %sp,%a0                     | point to start of vector table

    move.w  %d0,%a0@+                   | labWARM
    lea     %pc@(labCOLD),%a1           | initial warm start vector
    move.l  %a1,%a0@+                   | set vector

    move.w  %d0,%a0@+                   | Usrjmp
    lea     %pc@(labFCER),%a1           | initial user function vector
                                        | "Function call" error
    move.l  %a1,%a0@+                   | set vector

    move.w  %d0,%a0@+                   | V_INPT jmp opcode
    lea     %pc@(VEC_IN),%a1            | get byte from input device vector
    move.l  %a1,%a0@+                   | set vector

    move.w  %d0,%a0@+                   | V_OUTP jmp opcode
    lea     %pc@(VEC_OUT),%a1           | send byte to output device vector
    move.l  %a1,%a0@+                   | set vector

    move.w  %d0,%a0@+                   | V_LOAD jmp opcode
    lea     %pc@(VEC_LD),%a1            | load BASIC program vector
    move.l  %a1,%a0@+                   | set vector

    move.w  %d0,%a0@+                   | V_SAVE jmp opcode
    lea     %pc@(VEC_SV),%a1            | save BASIC program vector
    move.l  %a1,%a0@+                   | set vector

    move.w  %d0,%a0@+                   | V_CTLC jmp opcode
    lea     %pc@(VEC_CC),%a1            | save CTRL-C check vector
    move.l  %a1,%a0@+                   | set vector
    


| set-up start values

|##labGMEM

    moveq   #0x00,%d0                   | clear d0
    move.b  %d0,%a3@(Nullct)            | default NULL count
    move.b  %d0,%a3@(TPos)              | clear terminal position
    move.b  %d0,%a3@(ccflag)            | allow CTRL-C check
    move.w  %d0,%a3@(prg_strt-2)        | clear start word
    move.w  %d0,%a3@(BHsend)            | clear value to string end word

    move.b  #0x50,%a3@(TWidth)          | default terminal width byte for simulator
    move.b  #0x0E,%a3@(TabSiz)          | save default tab size = 14

    move.b  #0x38,%a3@(Iclim)           | default limit for TAB = 14 for simulator

    lea     %a3@(des_sk),%a4            | set descriptor stack start

    lea     %a3@(prg_strt),%a0          | get start of mem
    move.l  %a0,%a3@(Smeml)             | save start of mem



    bsr     lab1463                     | do "NEW" and "CleaR"

    bsr     labCRLF                     | print CR/LF

    move.l  %a3@(Ememl),%d0             | get end of mem
    sub.l   %a3@(Smeml),%d0             | subtract start of mem


    bsr     lab295E                     | print d0 as unsigned integer (bytes free)

    lea     %pc@(labSMSG),%a0           | point to start message
    bsr     lab18C3                     | print null terminated string from memory


    lea     %pc@(labRSED),%a0           | get pointer to value
    bsr     labUFAC                     | unpack memory %a0@ into FAC1


    lea     %pc@(lab1274),%a0           | get warm start vector
    move.l  %a0,%a3@(Wrmjpv)            | set warm start vector
    bsr     labRND                      | initialise

    jmp     %a3@(labWARM)               | go do warm start


|************************************************************************************
|
| do format error

labFOER:
    moveq   #0x2C,%d7    | error code 0x2C "Format" error
    bra     labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do address error

labADER:
    moveq   #0x2A,%d7    | error code 0x2A "Address" error
    bra     labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do wrong dimensions error

labWDER:
    moveq   #0x28,%d7    | error code 0x28 "Wrong dimensions" error
    bra     labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do undimensioned array error

labUDER:
    moveq   #0x26,%d7    | error code 0x26 "undimensioned array" error
    bra     labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do undefined variable error

labUVER:

| if you do want a non existant variable to return an error then leave the novar
| value at the top of this file set to zero

    .ifdef novar
    moveq   #0x24,%d7    | error code 0x24 "undefined variable" error
    bra     labXERR    | do error #%d7, then warm start
    .endif

| if you want a non existant variable to return a null value then set the novar
| value at the top of this file to some non zero value

|    .ifndef    novar
    .ifndef novar
    add.l    %d0,%d0    | .......0x .......& ........ .......0
    swap    %d0    | ........ .......0 .......0x .......&
    ror.b    #1,%d0    | ........ .......0 .......0x &.......
    lsr.w    #1,%d0    | ........ .......0 0....... 0x&.....≠.
    and.b    #0xC0,%d0    | mask the type bits
    move.b    %d0,%a3@(Dtypef)    | save the data type

    moveq    #0,%d0    | clear d0 and set the zero flag
    movea.l    %d0,%a0    | return a null address
    rts
    .endif

|************************************************************************************
|
| do loop without do error

labLDER:
    moveq    #0x22,%d7    | error code 0x22 "LOOP without DO" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do undefined function error

labUFER:
    moveq    #0x20,%d7    | error code 0x20 "Undefined function" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do cant continue error

labCCER:
    moveq    #0x1E,%d7    | error code 0x1E "Cant continue" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do string too complex error

labSCER:
    moveq    #0x1C,%d7    | error code 0x1C "String too complex" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do string too long error

labSLER:
    moveq    #0x1A,%d7    | error code 0x1A "String too long" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do type missmatch error

labTMER:
    moveq    #0x18,%d7    | error code 0x18 "Type mismatch" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do illegal direct error

labIDER:
    moveq    #0x16,%d7    | error code 0x16 "Illegal direct" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do divide by zero error

labDZER:
    moveq    #0x14,%d7    | error code 0x14 "Divide by zero" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do double dimension error

labDDER:
    moveq    #0x12,%d7    | error code 0x12 "Double dimension" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do array bounds error

labABER:
    moveq    #0x10,%d7    | error code 0x10 "Array bounds" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do undefined satement error

labUSER:
    moveq    #0x0E,%d7    | error code 0x0E "Undefined statement" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do out of memory error

labOMER:
    moveq    #0x0C,%d7    | error code 0x0C "Out of memory" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do overflow error

labOFER:
    moveq    #0x0A,%d7    | error code 0x0A "Overflow" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do function call error

labFCER:
    moveq    #0x08,%d7    | error code 0x08 "Function call" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do out of data error

labODER:
    moveq    #0x06,%d7    | error code 0x06 "Out of DATA" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do return without gosub error

labRGER:
    moveq    #0x04,%d7    | error code 0x04 "RETURN without GOSUB" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do syntax error

labSNER:
    moveq    #0x02,%d7    | error code 0x02 "Syntax" error
    bra      labXERR    | do error #%d7, then warm start


|************************************************************************************
|
| do next without for error

labNFER:
    moveq    #0x00,%d7    | error code 0x00 "Next without FOR" error


|************************************************************************************
|
| do error #%d7, then warm start

labXERR:
    bsr    lab1491    | flush stack & clear continue flag
    bsr    labCRLF    | print CR/LF
    lea    %pc@(labBAER),%a1    | start of error message pointer table
    move.w    (%a1,%d7.w),%d7    | get error message offset
    lea    (%a1,%d7.w),%a0    | get error message address
    bsr    lab18C3    | print null terminated string from memory
    lea    %pc@(labEMSG),%a0    | point to " Error" message
lab1269:
    bsr    lab18C3    | print null terminated string from memory
    move.l    %a3@(Clinel),%d0    | get current line
    bmi      lab1274    | go do warm start if -ve # (was immediate mode)

            | else print line number
    bsr    lab2953    | print " in line [LINE #]"

| BASIC warm start entry point, wait for Basic command

lab1274:
    lea    %pc@(labRMSG),%a0    | point to "Ready" message
    bsr    lab18C3    | go do print string

| wait for Basic command - no "Ready"

lab127D:
    moveq    #-1,%d1    | set to -1
    move.l    %d1,%a3@(Clinel)    | set current line #
    move.b    %d1,%a3@(Breakf)    | set break flag
    lea    %a3@(Ibuffs),%a5    | set basic execute pointer ready for new line
lab127E:
    bsr    lab1357    | call for BASIC input
    bsr    labGBYT    | scan memory
    beq     lab127E    | loop while null

| got to interpret input line now ....

    bcs.s    lab1295    | branch if numeric character, handle new
            | BASIC line

            | no line number so do immediate mode, a5
            | points to the buffer start
    bsr    lab13A6    | crunch keywords into Basic tokens
            | crunch from %a5@, output to %a0@
            | returns ..
            | d2 is length, d1 trashed, d0 trashed,
            | a1 trashed
    bra    lab15F6    | go scan & interpret code


|************************************************************************************
|
| handle a new BASIC line

lab1295:
    bsr    labGFPN    | get fixed-point number into temp integer & d1
    bsr    lab13A6    | crunch keywords into Basic tokens
            | crunch from %a5@, output to %a0@
            | returns .. d2 is length,
            | d1 trashed, d0 trashed, a1 trashed
    move.l    %a3@(Itemp),%d1    | get required line #
    bsr    labSSLN    | search BASIC for d1 line number
            | returns pointer in a0
    bcs.s    lab12E6    | branch if not found

            | aroooogah! line # already exists! delete it
    movea.l    %a0@,%a1    | get start of block (next line pointer)
    move.l    %a3@(Sfncl),%d0    | get end of block (start of functions)
    sub.l    %a1,%d0    | subtract start of block ( = bytes to move)
    lsr.l    #1,%d0    | /2 (word move)
    subq.l    #1,%d0    | adjust for dbf loop
    swap    %d0    | swap high word to low word
    movea.l    %a0,%a2    | copy destination
lab12AE:
    swap    %d0    | swap high word to low word
lab12B0:
    move.w    %a1@+,%a2@+    | copy word
    dbf    %d0,lab12B0    | decrement low count and loop until done

    swap    %d0    | swap high word to low word
    dbf    %d0,lab12AE    | decrement high count and loop until done

    move.l    %a2,%a3@(Sfncl)    | start of functions
    move.l    %a2,%a3@(Svarl)    | save start of variables
    move.l    %a2,%a3@(Sstrl)    | start of strings
    move.l    %a2,%a3@(Sarryl)    | save start of arrays
    move.l    %a2,%a3@(Earryl)    | save end of arrays

            | got new line in buffer and no existing same #
lab12E6:
    move.b    %a3@(Ibuffs),%d0    | get byte from start of input buffer
    beq      lab1325    | if null line go do line chaining

            | got new line and it isnt empty line
    movea.l    %a3@(Sfncl),%a1    | get start of functions (end of block to move)
    lea    8(%a1,%d2),%a2    | copy it, add line length and add room for
            | pointer and line number

    move.l    %a2,%a3@(Sfncl)    | start of functions
    move.l    %a2,%a3@(Svarl)    | save start of variables
    move.l    %a2,%a3@(Sstrl)    | start of strings
    move.l    %a2,%a3@(Sarryl)    | save start of arrays
    move.l    %a2,%a3@(Earryl)    | save end of arrays
    move.l    %a3@(Ememl),%a3@(Sstorl)    | copy end of mem to start of strings, clear
            | strings

    move.l    %a1,%d1    | copy end of block to move
    sub.l    %a0,%d1    | subtract start of block to move
    lsr.l    #1,%d1    | /2 (word copy)
    subq.l    #1,%d1    | correct for loop end on -1
    swap    %d1    | swap high word to low word
lab12FF:
    swap    %d1    | swap high word to low word
lab1301:
    move.w    %a1@-,%a2@-    | decrement pointers and copy word
    dbf    %d1,lab1301    | decrement & loop

    swap    %d1    | swap high word to low word
    dbf    %d1,lab12FF    | decrement high count and loop until done

| space is opened up, now copy the crunched line from the input buffer into the space

    lea    %a3@(Ibuffs),%a1    | source is input buffer
    movea.l    %a0,%a2    | copy destination
    moveq    #-1,%d1    | set to allow re-chaining
    move.l    %d1,%a2@+    | set next line pointer (allow re-chaining)
    move.l    %a3@(Itemp),%a2@+    | save line number
    lsr.w    #1,%d2    | /2 (word copy)
    subq.w    #1,%d2    | correct for loop end on -1
lab1303:
    move.w    %a1@+,%a2@+    | copy word
    dbf    %d2,lab1303    | decrement & loop

    bra      lab1325    | go test for end of prog

| rebuild chaining of BASIC lines

lab132E:
    addq.w    #8,%a0    | point to first code byte of line, there is
            | always 1 byte + [EOL] as null entries are
            | deleted
lab1330:
    tst.b    %a0@+    | test byte    
    bne.s    lab1330    | loop if not [EOL]

            | was [EOL] so get next line start
    move.w    %a0,%d1    | past pad byte(s)
    andi.w    #1,%d1    | mask odd bit
    add.w    %d1,%a0    | add back to ensure even
    move.l    %a0,%a1@    | save next line pointer to current line
lab1325:
    movea.l    %a0,%a1    | copy pointer for this line
    tst.l    %a0@    | test pointer to next line
    bne.s    lab132E    | not end of program yet so we must
            | go and fix the pointers

    bsr    lab1477    | reset execution to start, clear variables
            | and flush stack
    bra    lab127D    | now we just wait for Basic command, no "Ready"


|************************************************************************************
|
| receive a line from the keyboard
            | character 0x08 as delete key, BACKSPACE on
            | standard keyboard
lab134B:
    bsr    labPRNA    | go print the character
    moveq    #' ',%d0    | load [SPACE]
    bsr    labPRNA    | go print
    moveq    #0x08,%d0    | load [BACKSPACE]
    bsr    labPRNA    | go print
    subq.w    #0x01,%d1    | decrement the buffer index (delete)
    bra      lab1359    | re-enter loop

| print "? " and get BASIC input
| return a0 pointing to the buffer start

labINLN:
    bsr    lab18E3    | print "?" character
    moveq    #' ',%d0    | load " "
    bsr    labPRNA    | go print

| call for BASIC input (main entry point)
| return a0 pointing to the buffer start

lab1357:
    moveq    #0x00,%d1    | clear buffer index
    lea    %a3@(Ibuffs),%a0    | set buffer base pointer
lab1359:
    jsr    %a3@(V_INPT)    | call scan input device
    bcc      lab1359    | loop if no byte

    beq     lab1359    | loop if null byte

    cmp.b    #0x07,%d0    | compare with [BELL]
    beq     lab1378    | branch if [BELL]

    cmp.b    #0x0D,%d0    | compare with [CR]
    beq    lab1866    | do CR/LF exit if [CR]

    tst.w    %d1    | set flags on buffer index
    bne.s    lab1374    | branch if not empty

| the next two lines ignore any non printing character and [SPACE] if the input buffer
| is empty

    cmp.b    #' ',%d0    | compare with [SP]+1
    bls.s    lab1359    | if < ignore character

|##    cmp.b    #' '+1,%d0    | compare with [SP]+1
|##    bcs.s    lab1359    | if < ignore character

lab1374:
    cmp.b    #0x08,%d0    | compare with [BACKSPACE]
    beq     lab134B    | go delete last character

lab1378:
    cmp.w    #(Ibuffe-Ibuffs-1),%d1    | compare character count with max-1
    bcc      lab138E    | skip store & do [BELL] if buffer full

    move.b    %d0,(%a0,%d1.w)    | else store in buffer
    addq.w    #0x01,%d1    | increment index
lab137F:
    bsr    labPRNA    | go print the character
    bra      lab1359    | always loop for next character

| announce buffer full

lab138E:
    moveq    #0x07,%d0    | [BELL] character into d0
    bra      lab137F    | go print the [BELL] but ignore input character


|************************************************************************************
|
| copy a hex value without crunching

lab1392:
    move.b    %d0,(%a0,%d2.w)    | save the byte to the output
    addq.w    #1,%d2    | increment the buffer save index

    addq.w    #1,%d1    | increment the buffer read index
    move.b    (%a5,%d1.w),%d0    | get a byte from the input buffer
    beq    lab13EC    | if [EOL] go save it without crunching

    cmp.b    #' ',%d0    | compare the character with " "
    beq     lab1392    | if [SPACE] just go save it and get another

    cmp.b    #'0',%d0    | compare the character with "0"
    bcs.s    lab13C6    | if < "0" quit the hex save loop

    cmp.b    #'9',%d0    | compare with "9"
    bls.s    lab1392    | if it is "0" to "9" save it and get another

    moveq    #-33,%d5    | mask xx0x xxxx, ASCII upper case
    and.b    %d0,%d5    | mask the character

    cmp.b    #'A',%d5    | compare with "A"
    bcs.s    lab13CC    | if < "A" quit the hex save loop

    cmp.b    #'F',%d5    | compare with "F"
    bls.s    lab1392    | if it is "A" to "F" save it and get another

    bra      lab13CC    | else continue crunching

| crunch keywords into Basic tokens
| crunch from %a5@, output to %a0@
| returns ..
| d4 trashed
| d3 trashed
| d2 is length
| d1 trashed
| d0 trashed
| a1 trashed

| this is the improved BASIC crunch routine and is 10 to 100 times faster than the
| old list search

lab13A6:
    moveq    #0,%d1    | clear the read index
    move.l    %d1,%d2    | clear the save index
    move.b    %d1,%a3@(Oquote)    | clear the open quote/DATA flag
lab13AC:
    moveq    #0,%d0    | clear word
    move.b    (%a5,%d1.w),%d0    | get byte from input buffer
    beq     lab13EC    | if null save byte then continue crunching

    cmp.b    #'_',%d0    | compare with "_"
    bcc      lab13EC    | if >= "_" save byte then continue crunching

    cmp.b    #'<',%d0    | compare with "<"
    bcc      lab13CC    | if >= "<" go crunch

    cmp.b    #'0',%d0    | compare with "0"
    bcc      lab13EC    | if >= "0" save byte then continue crunching

    move.b    %d0,%a3@(Asrch)    | save buffer byte as search character
    cmp.b    #0x22,%d0    | is it quote character?
    beq     lab1410    | branch if so (copy quoted string)

    cmp.b    #'$',%d0    | is it the hex value character? ($)
    beq     lab1392    | if so go copy a hex value

lab13C6:
    cmp.b    #0x2A,%d0    | compare with "*"
    bcs.s    lab13EC    | if <= "*" save byte then continue crunching

            | crunch rest
lab13CC:
    btst.b    #6,%a3@(Oquote)    | test open quote/DATA token flag
    bne.s    lab13EC    | branch if b6 of Oquote set (was DATA)
            | go save byte then continue crunching

    sub.b    #0x2A,%d0    | normalise byte
    add.w    %d0,%d0    | |2 makes word offset (high byte=0x00)
    lea    %pc@(TAB_CHRT),%a1    | get keyword offset table address
    move.w    (%a1,%d0.w),%d0    | get offset into keyword table
    bmi      lab141F    | branch if no keywords for character

    lea    %pc@(TAB_STAR),%a1    | get keyword table address
    adda.w    %d0,%a1    | add keyword offset
    moveq    #-1,%d3    | clear index
    move.w    %d1,%d4    | copy read index
lab13D6:
    addq.w    #1,%d3    | increment table index
    move.b    (%a1,%d3.w),%d0    | get byte from table
lab13D8:
    bmi      lab13EA    | branch if token, save token and continue
            | crunching

    addq.w    #1,%d4    | increment read index
    cmp.b    (%a5,%d4.w),%d0    | compare byte from input buffer
    beq     lab13D6    | loop if character match

    bra      lab1417    | branch if no match

lab13EA:
    move.w    %d4,%d1    | update read index
lab13EC:
    move.b    %d0,(%a0,%d2.w)    | save byte to output
    addq.w    #1,%d2    | increment buffer save index
    addq.w    #1,%d1    | increment buffer read index
    tst.b    %d0    | set flags
    beq     lab142A    | branch if was null [EOL]

            | d0 holds token or byte here
    sub.b    #0x3A,%d0    | subtract ":"
    beq     lab13FF    | branch if it was ":" (is now 0x00)

            | d0 now holds token-0x3A
    cmp.b    #(TK_DATA-0x3A),%d0    | compare with DATA token - 0x3A
    bne.s    lab1401    | branch if not DATA

            | token was : or DATA
lab13FF:
    move.b    %d0,%a3@(Oquote)    | save token-0x3A (0x00 for ":", TK_DATA-0x3A for
            | DATA)
lab1401:
    sub.b    #(TK_REM-0x3A),%d0    | subtract REM token offset
    bne    lab13AC    | If wasnt REM then go crunch rest of line

    move.b    %d0,%a3@(Asrch)    | else was REM so set search for [EOL]

            | loop for REM, "..." etc.
lab1408:
    move.b    (%a5,%d1.w),%d0    | get byte from input buffer
    beq     lab13EC    | branch if null [EOL]

    cmp.b    %a3@(Asrch),%d0    | compare with stored character
    beq     lab13EC    | branch if match (end quote, REM, :, or DATA)

            | entry for copy string in quotes, dont crunch
lab1410:
    move.b    %d0,(%a0,%d2.w)    | save byte to output
    addq.w    #1,%d2    | increment buffer save index
    addq.w    #1,%d1    | increment buffer read index
    bra      lab1408    | loop

| not found keyword this go so find the end of this word in the table

lab1417:
    move.w    %d1,%d4    | reset read pointer
lab141B:
    addq.w    #1,%d3    | increment keyword table pointer, flag
            | unchanged
    move.b    (%a1,%d3.w),%d0    | get keyword table byte
    bpl.s    lab141B    | if not end of keyword go do next byte

    addq.w    #1,%d3    | increment keyword table pointer flag
            | unchanged
    move.b    (%a1,%d3.w),%d0    | get keyword table byte
    bne.s    lab13D8    | go test next word if not zero byte (table end)

            | reached end of table with no match
lab141F:
    move.b    (%a5,%d1.w),%d0    | restore byte from input buffer
    bra      lab13EC    | go save byte in output and continue crunching

            | reached [EOL]
lab142A:
    moveq    #0,%d0    | ensure longword clear
    btst    %d0,%d2    | test odd bit (fastest)
    beq     lab142C    | branch if no bytes to fill

    move.b    %d0,(%a0,%d2.w)    | clear next byte
    addq.w    #1,%d2    | increment buffer save index
lab142C:
    move.l    %d0,(%a0,%d2.w)    | clear next line pointer, EOT in immediate mode
    rts


|************************************************************************************
|
| search Basic for d1 line number from start of mem

labSSLN:
    movea.l    %a3@(Smeml),%a0    | get start of program mem
    bra      labSCLN    | go search for required line from a0

lab145F:
    movea.l    %d0,%a0    | copy next line pointer

| search Basic for d1 line number from a0
| returns Cb=0 if found
| returns a0 pointer to found or next higher (not found) line

labSCLN:
    move.l    %a0@+,%d0    | get next line pointer and point to line #
    beq     lab145E    | is end marker so were done, do 'no line' exit

    cmp.l    %a0@,%d1    | compare this line # with required line #
    bgt.s    lab145F    | loop if required # > this #

    subq.w    #4,%a0    | adjust pointer, flags not changed
    rts

lab145E:
    subq.w    #4,%a0    | adjust pointer, flags not changed
    subq.l    #1,%d0    | make end program found = -1, set carry
    rts


|************************************************************************************
|
| perform NEW

labNEW:
    bne     rts_005    | exit if not end of statement (do syntax error)

lab1463:
    movea.l    %a3@(Smeml),%a0    | point to start of program memory
    moveq    #0,%d0    | clear longword
    move.l    %d0,%a0@+    | clear first line, next line pointer
    move.l    %a0,%a3@(Sfncl)    | set start of functions

| reset execution to start, clear variables and flush stack

lab1477:
    movea.l    %a3@(Smeml),%a5    | reset BASIC execute pointer
    subq.w    #1,%a5    | -1 (as end of previous line)

| "CLEAR" command gets here

lab147A:
    move.l    %a3@(Ememl),%a3@(Sstorl)    | save end of mem as bottom of string space
    move.l    %a3@(Sfncl),%d0    | get start of functions
    move.l    %d0,%a3@(Svarl)    | start of variables
    move.l    %d0,%a3@(Sstrl)    | start of strings
    move.l    %d0,%a3@(Sarryl)    | set start of arrays
    move.l    %d0,%a3@(Earryl)    | set end of arrays
lab1480:
    moveq    #0,%d0    | set Zb
    move.b    %d0,%a3@(ccnull)    | clear get byte countdown
    bsr    labRESTORE    | perform RESTORE command

| flush stack & clear continue flag

lab1491:
    lea    %a3@(des_sk),%a4    | reset descriptor stack pointer

    move.l    %sp@+,%d0    | pull return address
    lea    %a3@(ram_base),%sp    | set stack to RAM start + 1k, flush stack
    move.l    %d0,%sp@-    | restore return address

    moveq    #0,%d0    | clear longword
    move.l    %d0,%a3@(Cpntrl)    | clear continue pointer
    move.b    %d0,%a3@(Sufnxf)    | clear subscript/FNX flag
rts_005:
    rts


|************************************************************************************
|
| perform CLEAR

labCLEAR:
    beq     lab147A    | if no following byte go do "CLEAR"

    rts    | was following byte (go do syntax error)


|************************************************************************************
|
| perform LIST [n][-m]

labLIST:
    bcs.s    lab14BD    | branch if next character numeric (LIST n...)

    moveq    #-1,%d1    | set end to 0xFFFFFFFF
    move.l    %d1,%a3@(Itemp)    | save to Itemp

    moveq    #0,%d1    | set start to 0x00000000
    tst.b    %d0    | test next byte
    beq     lab14C0    | branch if next character [NULL] (LIST)

    cmp.b    #TK_MINUS,%d0    | compare with token for -
    bne.s    rts_005    | exit if not - (LIST -m)

            | LIST [[n]-[m]] this sets the n, if present,
            | as the start and end
lab14BD:
    bsr    labGFPN    | get fixed-point number into temp integer & d1
lab14C0:
    bsr    labSSLN    | search BASIC for d1 line number
            | (pointer in a0)
    bsr    labGBYT    | scan memory
    beq     lab14D4    | branch if no more characters

            | this bit checks the - is present
    cmp.b    #TK_MINUS,%d0    | compare with token for -
    bne.s    rts_005    | return if not "-" (will be Syntax error)

    moveq    #-1,%d1    | set end to 0xFFFFFFFF
    move.l    %d1,%a3@(Itemp)    | save Itemp

            | LIST [n]-[m] the - was there so see if
            | there is an m to set as the end value
    bsr    labIGBY    | increment & scan memory
    beq     lab14D4    | branch if was [NULL] (LIST n-)

    bsr    labGFPN    | get fixed-point number into temp integer & d1
lab14D4:
    move.b    #0x00,%a3@(Oquote)    | clear open quote flag
    bsr    labCRLF    | print CR/LF
    move.l    %a0@+,%d0    | get next line pointer
    beq     rts_005    | if null all done so exit

    movea.l    %d0,%a1    | copy next line pointer
    bsr    lab1629    | do CRTL-C check vector

    move.l    %a0@+,%d0    | get this line #
    cmp.l    %a3@(Itemp),%d0    | compare end line # with this line #
    BHI.s    rts_005    | if this line greater all done so exit

lab14E2:
    movem.l    %a0-%a1,%sp@-    | save registers
    bsr    lab295E    | print d0 as unsigned integer
    movem.l    %sp@+,%a0-%a1    | restore registers
    moveq    #0x20,%d0    | space is the next character
lab150C:
    bsr    labPRNA    | go print the character
    cmp.b    #0x22,%d0    | was it double-quote character
    bne.s    lab1519    | branch if not

            | we are either entering or leaving quotes
    eor.b    #0xFF,%a3@(Oquote)    | toggle open quote flag
lab1519:
    move.b    %a0@+,%d0    | get byte and increment pointer
    bne.s    lab152E    | branch if not [EOL] (go print)

            | was [EOL]
    movea.l    %a1,%a0    | copy next line pointer
    move.l    %a0,%d0    | copy to set flags
    bne.s    lab14D4    | go do next line if not [EOT]

    rts

lab152E:
    bpl.s    lab150C    | just go print it if not token byte

            | else it was a token byte so maybe uncrunch it
    tst.b    %a3@(Oquote)    | test the open quote flag
    bmi      lab150C    | just go print character if open quote set

            | else uncrunch BASIC token
    lea    %pc@(labKEYT),%a2    | get keyword table address
    moveq    #0x7F,%d1    | mask into d1
    and.b    %d0,%d1    | copy and mask token
    lsl.w    #2,%d1    | |4
    lea    (%a2,%d1.w),%a2    | get keyword entry address
    move.b    %a2@+,%d0    | get byte from keyword table
    bsr    labPRNA    | go print the first character
    moveq    #0,%d1    | clear d1
    move.b    %a2@+,%d1    | get remaining length byte from keyword table
    bmi      lab1519    | if -ve done so go get next byte

    move.w    %a2@,%d0    | get offset to rest
    lea    %pc@(TAB_STAR),%a2    | get keyword table address
    lea    (%a2,%d0.w),%a2    | get address of rest
lab1540:
    move.b    %a2@+,%d0    | get byte from keyword table
    bsr    labPRNA    | go print the character
    dbf    %d1,lab1540    | decrement and loop if more to do

    bra      lab1519    | go get next byte


|************************************************************************************
|
| perform FOR

labFOR:
    bsr    labLET    | go do LET

    move.l    %a3@(Lvarpl),%d0    | get the loop variable pointer
    cmp.l    %a3@(Sstrl),%d0    | compare it with the end of vars memory
    bge    labTMER    | if greater go do type mismatch error

| test for not less than the start of variables memory if needed
|
|    cmp.l    %a3@(Svarl),%d0    | compare it with the start of variables memory
|    blt    labTMER    | if not variables memory do type mismatch error

|    moveq    #28,%d0    | we need 28 bytes !
|    bsr      lab1212    | check room on stack for d0 bytes

    bsr    labSNBS    | scan for next BASIC statement ([:] or [EOL])
            | returns a0 as pointer to [:] or [EOL]
    move.l    %a0,%sp@    | push onto stack (and dump the return address)
    move.l    %a3@(Clinel),%sp@-    | push current line onto stack

    move.L    #TK_TO-0x100,%d0    | set "TO" token
    bsr    labSCCA    | scan for CHR$(d0) else syntax error/warm start
    bsr    labCTNM    | check if source is numeric, else type mismatch
    move.b    %a3@(Dtypef),%sp@-    | push the FOR variable data type onto stack
    bsr    labEVNM    | evaluate expression and check is numeric else
            | do type mismatch

    move.l    %a3@(FAC1_m),%sp@-    | push TO value mantissa
    move.w    %a3@(FAC1_e),%sp@-    | push TO value exponent and sign

    move.l    #0x80000000,%a3@(FAC1_m)    | set default STEP size mantissa
    move.w    #0x8100,%a3@(FAC1_e)    | set default STEP size exponent and sign

    bsr    labGBYT    | scan memory
    cmp.b    #TK_STEP,%d0    | compare with STEP token
    bne.s    lab15B3    | jump if not "STEP"

            | was STEP token so ....
    bsr    labIGBY    | increment & scan memory
    bsr    labEVNM    | evaluate expression & check is numeric
            | else do type mismatch
lab15B3:
    move.l    %a3@(FAC1_m),%sp@-    | push STEP value mantissa
    move.w    %a3@(FAC1_e),%sp@-    | push STEP value exponent and sign

    move.l    %a3@(Lvarpl),%sp@-    | push variable pointer for FOR/NEXT
    move.w    #TK_FOR,%sp@-    | push FOR token on stack

    bra      lab15C2    | go do interpreter inner loop

lab15DC:    | have reached [EOL]+1
    move.w    %a5,%d0    | copy BASIC execute pointer
    and.w    #1,%d0    | and make line start address even
    add.w    %d0,%a5    | add to BASIC execute pointer
    move.l    %a5@+,%d0    | get next line pointer
    beq    lab1274    | if null go to immediate mode, no "BREAK"
            | message (was immediate or [EOT] marker)

    move.l    %a5@+,%a3@(Clinel)    | save (new) current line #
lab15F6:
    bsr    labGBYT    | get BASIC byte
    bsr      lab15FF    | go interpret BASIC code from %a5@

| interpreter inner loop (re)entry point

lab15C2:
    bsr      lab1629    | do CRTL-C check vector
    tst.b    %a3@(Clinel)    | test current line #, is -ve for immediate mode
    bmi      lab15D1    | branch if immediate mode

    move.l    %a5,%a3@(Cpntrl)    | save BASIC execute pointer as continue pointer
lab15D1:
    move.b    %a5@+,%d0    | get this byte & increment pointer
    beq     lab15DC    | loop if [EOL]

    cmp.b    #0x3A,%d0    | compare with ":"
    beq     lab15F6    | loop if was statement separator

    bra    labSNER    | else syntax error, then warm start


|************************************************************************************
|
| interpret BASIC code from %a5@

lab15FF:
    beq    rts_006    | exit if zero [EOL]

lab1602:
    eori.b    #0x80,%d0    | normalise token
    bmi    labLET    | if not token, go do implied LET

    cmp.b    #(TK_TAB-0x80),%d0    | compare normalised token with TAB
    bcc    labSNER    | branch if d0>=TAB, syntax error/warm start
            | only tokens before TAB can start a statement

    ext.w    %d0    | byte to word (clear high byte)
    add.w    %d0,%d0    | |2
    lea    %pc@(labCTBL),%a0    | get vector table base address
    move.w    (%a0,%d0.w),%d0    | get offset to vector
    pea    (%a0,%d0.w)    | push vector
    bra    labIGBY    | get following byte & execute vector


|************************************************************************************
|
| CTRL-C check jump. this is called as a subroutine but exits back via a jump if a
| key press is detected.

lab1629:
    jmp    %a3@(V_CTLC)    | ctrl c check vector

| if there was a key press it gets back here .....

lab1636:
    cmp.b    #0x03,%d0    | compare with CTRL-C
    beq     lab163B    | STOP if was CTRL-C

lab1639:
    rts    |


|************************************************************************************
|
| perform END

labEND:
    bne.s    lab1639    | exit if something follows STOP
    move.b    #0,%a3@(Breakf)    | clear break flag, indicate program end


|************************************************************************************
|
| perform STOP

labSTOP:
    bne.s    lab1639    | exit if something follows STOP

lab163B:
    lea    %a3@(Ibuffe),%a1    | get buffer end
    cmpA.l    %a1,%a5    | compare execute address with buffer end
    bcs.s    lab164F    | branch if BASIC pointer is in buffer
            | cant continue in immediate mode

            | else...
    move.l    %a5,%a3@(Cpntrl)    | save BASIC execute pointer as continue pointer
lab1647:
    move.l    %a3@(Clinel),%a3@(Blinel)    | save break line
lab164F:
    addq.w    #4,%sp    | dump return address, dont return to execute
            | loop
    move.b    %a3@(Breakf),%d0    | get break flag
    beq    lab1274    | go do warm start if was program end

    lea    %pc@(labBMSG),%a0    | point to "Break"
    bra    lab1269    | print "Break" and do warm start


|************************************************************************************
|
| perform RESTORE

labRESTORE:
    movea.l    %a3@(Smeml),%a0    | copy start of memory
    beq     lab1624    | branch if next character null (RESTORE)

    bsr    labGFPN    | get fixed-point number into temp integer & d1
    cmp.l    %a3@(Clinel),%d1    | compare current line # with required line #
    bls.s    labGSCH    | branch if >= (start search from beginning)

    movea.l    %a5,%a0    | copy BASIC execute pointer
labRESs:
    tst.b    %a0@+    | test next byte & increment pointer
    bne.s    labRESs    | loop if not EOL

    move.w    %a0,%d0    | copy pointer
    and.w    #1,%d0    | mask odd bit
    add.w    %d0,%a0    | add pointer
            | search for line in Itemp from %a0@
labGSCH:
    bsr    labSCLN    | search for d1 line number from a0
            | returns Cb=0 if found
    bcs    labUSER    | go do "Undefined statement" error if not found

lab1624:
    tst.b    %a0@-    | decrement pointer (faster)
    move.l    %a0,%a3@(Dptrl)    | save DATA pointer
rts_006:
    rts


|************************************************************************************
|
| perform NULL

labNULL:
    bsr    labGTBY    | get byte parameter, result in d0 and Itemp
    move.b    %d0,%a3@(Nullct)    | save new NULL count
    rts


|************************************************************************************
|
| perform CONT

labCONT:
    bne    labSNER    | if following byte exit to do syntax error

    tst.b    %a3@(Clinel)    | test current line #, is -ve for immediate mode
    bpl    labCCER    | if running go do cant continue error

    move.l    %a3@(Cpntrl),%d0    | get continue pointer
    beq    labCCER    | go do cannot continue error if we cannot

            | we can continue so ...
    movea.l    %d0,%a5    | save continue pointer as BASIC execute pointer
    move.l    %a3@(Blinel),%a3@(Clinel)    | set break line as current line
    rts


|************************************************************************************
|
| perform RUN

labRUN:
    bne.s    labRUNn    | if following byte do RUN n

    bsr    lab1477    | execution to start, clear vars & flush stack
    move.l    %a5,%a3@(Cpntrl)    | save as continue pointer
    bra    lab15C2    | go do interpreter inner loop
            | (cant rts, we flushed the stack!)

labRUNn:
    bsr    lab147A    | go do "CLEAR"
    bra      lab16B0    | get n and do GOTO n


|************************************************************************************
|
| perform DO

labDO:
|    move.l    #0x05,%d0    | need 5 bytes for DO
|    bsr      lab1212    | check room on stack for A bytes
    move.l    %a5,%sp@-    | push BASIC execute pointer on stack
    move.l    %a3@(Clinel),%sp@-    | push current line on stack
    move.w    #TK_DO,%sp@-    | push token for DO on stack
    pea    %pc@(lab15C2)    | set return address
    bra    labGBYT    | scan memory & return to interpreter inner loop


|************************************************************************************
|
| perform GOSUB

labGOSUB:
|    move.l    #10,%d0    | need 10 bytes for GOSUB
|    bsr      lab1212    | check room on stack for d0 bytes
    move.l    %a5,%sp@-    | push BASIC execute pointer
    move.l    %a3@(Clinel),%sp@-    | push current line
    move.w    #TK_GOSUB,%sp@-    | push token for GOSUB
lab16B0:
    bsr    labGBYT    | scan memory
    pea    %pc@(lab15C2)    | return to interpreter inner loop after GOTO n

| this pea is needed because either we just cleared the stack and have nowhere to return
| to or, in the case of GOSUB, we have just dropped a load on the stack and the address
| we whould have returned to is buried. This burried return address will be unstacked by
| the corresponding RETURN command


|************************************************************************************
|
| perform GOTO

labGOTO:
    bsr    labGFPN    | get fixed-point number into temp integer & d1
    movea.l    %a3@(Smeml),%a0    | get start of memory
    cmp.l    %a3@(Clinel),%d1    | compare current line with wanted #
    bls.s    lab16D0    | branch if current # => wanted #

    movea.l    %a5,%a0    | copy BASIC execute pointer
labGOTs:
    tst.b    %a0@+    | test next byte & increment pointer
    bne.s    labGOTs    | loop if not EOL

    move.w    %a0,%d0    | past pad byte(s)
    and.w    #1,%d0    | mask odd bit
    add.w    %d0,%a0    | add to pointer

lab16D0:
    bsr    labSCLN    | search for d1 line number from a0
            | returns Cb=0 if found
    bcs    labUSER    | if carry set go do "Undefined statement" error

    movea.l    %a0,%a5    | copy to basic execute pointer
    subq.w    #1,%a5    | decrement pointer
    move.l    %a5,%a3@(Cpntrl)    | save as continue pointer
    rts


|************************************************************************************
|
| perform LOOP

labLOOP:
    cmp.w    #TK_DO,%sp@(4)    | compare token on stack with DO token
    bne    labLDER    | branch if no matching DO

    move.b    %d0,%d7    | copy following token (byte)
    beq     LoopAlways    | if no following token loop forever

    cmp.b    #':',%d7    | compare with ":"
    beq     LoopAlways    | if no following token loop forever

    sub.b    #TK_UNTIL,%d7    | subtract token for UNTIL
    beq     DoRest    | branch if was UNTIL

    subq.b    #1,%d7    | decrement result
    bne    labSNER    | if not WHILE go do syntax error & warm start
            | only if the token was WHILE will this fail

    moveq    #-1,%d7    | set invert result longword
DoRest:
    bsr    labIGBY    | increment & scan memory
    bsr    labEVEX    | evaluate expression
    tst.b    %a3@(FAC1_e)    | test FAC1 exponent
    beq     DoCmp    | if = 0 go do straight compare

    move.b    #0xFF,%a3@(FAC1_e)    | else set all bits
DoCmp:
    eor.b    %d7,%a3@(FAC1_e)    | eor with invert byte
    bne.s    LoopDone    | if <> 0 clear stack & back to interpreter loop

            | loop condition wasnt met so do it again
LoopAlways:
    move.l    %sp@(6),%a3@(Clinel)    | copy DO current line
    move.l    %sp@(10),%a5    | save BASIC execute pointer

    lea    %pc@(lab15C2),%a0    | get return address
    move.l    %a0,%sp@    | dump the call to this routine and set the
            | return address
    bra    labGBYT    | scan memory and return to interpreter inner
            | loop

            | clear stack & back to interpreter loop
LoopDone:
    lea    %sp@(14),%sp    | dump structure and call from stack
    bra      labDATA    | go perform DATA (find : or [EOL])


|************************************************************************************
|
| perform RETURN

labRETURN:
    bne.s    rts_007    | exit if following token to allow syntax error

    cmp.w    #TK_GOSUB,%sp@(4)    | compare token from stack with GOSUB
    bne    labRGER    | do RETURN without GOSUB error if no matching
            | GOSUB

    addq.w    #6,%sp    | dump calling address & token
    move.l    %sp@+,%a3@(Clinel)    | pull current line
    move.l    %sp@+,%a5    | pull BASIC execute pointer
            | now do perform "DATA" statement as we could be
            | returning into the middle of an ON <var> GOSUB
            | n,m,p,q line (the return address used by the
            | DATA statement is the one pushed before the
            | GOSUB was executed!)


|************************************************************************************
|
| perform DATA

labDATA:
    bsr      labSNBS    | scan for next BASIC statement ([:] or [EOL])
            | returns a0 as pointer to [:] or [EOL]
    movea.l    %a0,%a5    | skip rest of statement
rts_007:
    rts


|************************************************************************************
|
| scan for next BASIC statement ([:] or [EOL])
| returns a0 as pointer to [:] or [EOL]

labSNBS:
    movea.l    %a5,%a0    | copy BASIC execute pointer
    moveq    #0x22,%d1    | set string quote character
    moveq    #0x3A,%d2    | set look for character = ":"
    bra      lab172D    | go do search

lab172C:
    cmp.b    %d0,%d2    | compare with ":"
    beq     rts_007a    | exit if found

    cmp.b    %d0,%d1    | compare with '"'
    beq     lab1725    | if found go search for [EOL]

lab172D:
    move.b    %a0@+,%d0    | get next byte
    bne.s    lab172C    | loop if not null [EOL]

rts_007a:
    subq.w    #1,%a0    | correct pointer
    rts

lab1723:
    cmp.b    %d0,%d1    | compare with '"'
    beq     lab172D    | if found go search for ":" or [EOL]

lab1725:
    move.b    %a0@+,%d0    | get next byte
    bne.s    lab1723    | loop if not null [EOL]

    bra      rts_007a    | correct pointer & return


|************************************************************************************
|
| perform IF

labIF:
    bsr    labEVEX    | evaluate expression
    bsr    labGBYT    | scan memory
    cmp.b    #TK_THEN,%d0    | compare with THEN token
    beq     lab174B    | if it was THEN then continue

            | wasnt IF .. THEN so must be IF .. GOTO
    cmp.b    #TK_GOTO,%d0    | compare with GOTO token
    bne    labSNER    | if not GOTO token do syntax error/warm start

            | was GOTO so check for GOTO <n>
    move.l    %a5,%a0    | save the execute pointer
    bsr    labIGBY    | scan memory, test for a numeric character
    move.l    %a0,%a5    | restore the execute pointer
    bcc    labSNER    | if not numeric do syntax error/warm start

lab174B:
    move.b    %a3@(FAC1_e),%d0    | get FAC1 exponent
    beq     lab174E    | if result was zero go look for an ELSE

    bsr    labIGBY    | increment & scan memory
    bcs    labGOTO    | if numeric do GOTO n
            | a GOTO <n> will never return to the IF
            | statement so there is no need to return
            | to this code

    cmp.b    #TK_RETURN,%d0    | compare with RETURN token
    beq    lab1602    | if RETURN then interpret BASIC code from %a5@
            | and dont return here

    bsr    lab15FF    | else interpret BASIC code from %a5@

| the IF was executed and there may be a following ELSE so the code needs to return
| here to check and ignore the ELSE if present

    move.b    %a5@,%d0    | get the next basic byte
    cmp.b    #TK_ELSE,%d0    | compare it with the token for ELSE
    beq    labDATA    | if ELSE ignore the following statement

| there was no ELSE so continue execution of IF <expr> THEN <stat> [: <stat>]. any
| following ELSE will, correctly, cause a syntax error

    rts    | else return to interpreter inner loop

| perform ELSE after IF

lab174E:
    move.b    %a5@+,%d0    | faster increment past THEN
    move.b    #TK_ELSE,%d3    | set search for ELSE token
    move.b    #TK_IF,%d4    | set search for IF token
    moveq    #0,%d5    | clear the nesting depth
lab1750:
    move.b    %a5@+,%d0    | get next BASIC byte & increment ptr
    beq     lab1754    | if EOL correct the pointer and return

    cmp.b    %d4,%d0    | compare with "IF" token
    bne.s    lab1752    | skip if not nested IF

    addq.w    #1,%d5    | else increment the nesting depth ..
    bra      lab1750    | .. and continue looking

lab1752:
    cmp.b    %d3,%d0    | compare with ELSE token
    bne.s    lab1750    | if not ELSE continue looking

lab1756:
    dbf    %d5,lab1750    | loop if still nested

| found the matching ELSE, now do <{n|statement}>

    bsr    labGBYT    | scan memory
    bcs    labGOTO    | if numeric do GOTO n
            | code will return to the interpreter loop
            | at the tail end of the GOTO <n>

    bra    lab15FF    | else interpret BASIC code from %a5@
            | code will return to the interpreter loop
            | at the tail end of the <statement>


|************************************************************************************
|
| perform REM, skip (rest of) line

labREM:
    tst.b    %a5@+    | test byte & increment pointer
    bne.s    labREM    | loop if not EOL

lab1754:
    subq.w    #1,%a5    | correct the execute pointer
    rts


|************************************************************************************
|
| perform ON

labON:
    bsr    labGTBY    | get byte parameter, result in d0 and Itemp
    move.b    %d0,%d2    | copy byte
    bsr    labGBYT    | restore BASIC byte
    move.w    %d0,%sp@-    | push GOTO/GOSUB token
    cmp.b    #TK_GOSUB,%d0    | compare with GOSUB token
    beq     lab176C    | branch if GOSUB

    cmp.b    #TK_GOTO,%d0    | compare with GOTO token
    bne    labSNER    | if not GOTO do syntax error, then warm start

| next character was GOTO or GOSUB

lab176C:
    subq.b    #1,%d2    | decrement index (byte value)
    bne.s    lab1773    | branch if not zero

    move.w    %sp@+,%d0    | pull GOTO/GOSUB token
    bra    lab1602    | go execute it

lab1773:
    bsr    labIGBY    | increment & scan memory
    bsr      labGFPN    | get fixed-point number into temp integer & d1
            | (skip this n)
    cmp.b    #0x2C,%d0    | compare next character with ","
    beq     lab176C    | loop if ","

    move.w    %sp@+,%d0    | pull GOTO/GOSUB token (run out of options)
    rts    | and exit


|************************************************************************************
|
| get fixed-point number into temp integer & d1
| interpret number from %a5@, leave %a5@ pointing to byte after #

labGFPN:
    moveq    #0x00,%d1    | clear integer register
    move.l    %d1,%d0    | clear d0
    bsr    labGBYT    | scan memory, Cb=1 if "0"-"9", & get byte
    bcc      lab1786    | return if carry clear, chr was not "0"-"9"

    move.l    %d2,%sp@-    | save d2
lab1785:
    move.l    %d1,%d2    | copy integer register
    add.l    %d1,%d1    | |2
    bcs    labSNER    | if overflow do syntax error, then warm start

    add.l    %d1,%d1    | |4
    bcs    labSNER    | if overflow do syntax error, then warm start

    add.l    %d2,%d1    | |1 + |4
    bcs    labSNER    | if overflow do syntax error, then warm start

    add.l    %d1,%d1    | |10
    bcs    labSNER    | if overflow do syntax error, then warm start

    sub.b    #0x30,%d0    | subtract 0x30 from byte
    add.l    %d0,%d1    | add to integer register, the top 24 bits are
            | always clear
    BVS    labSNER    | if overflow do syntax error, then warm start
            | this makes the maximum line number 2147483647
    bsr    labIGBY    | increment & scan memory
    bcs.s    lab1785    | loop for next character if "0"-"9"

    move.l    %sp@+,%d2    | restore d2
lab1786:
    move.l    %d1,%a3@(Itemp)    | save Itemp
    rts


|************************************************************************************
|
| perform DEC

labDEC:
    move.w    #0x8180,%sp@-    | set -1 sign/exponent
    bra      lab17B7    | go do DEC


|************************************************************************************
|
| perform INC

labINC:
    move.w    #0x8100,%sp@-    | set 1 sign/exponent
    bra      lab17B7    | go do INC

            | was "," so another INCR variable to do
lab17B8:
    bsr    labIGBY    | increment and scan memory
lab17B7:
    bsr    labGVAR    | get variable address in a0

| if you want a non existant variable to return a null value then set the novar
| value at the top of this file to some non zero value

     .ifndef    novar

    beq     labINCT    | if variable not found skip the inc/dec

     .endif

    tst.b    %a3@(Dtypef)    | test data type, 0x80=string, 0x40=integer,
            | 0x00=float
    bmi    labTMER    | if string do "Type mismatch" error/warm start

    bne.s    labINCI    | go do integer INC/DEC

    move.l    %a0,%a3@(Lvarpl)    | save var address
    bsr    labUFAC    | unpack memory %a0@ into FAC1
    move.l    #0x80000000,%a3@(FAC2_m)    | set FAC2 mantissa for 1
    move.w    %sp@,%d0    | move exponent & sign to d0
    move.w    %d0,%a3@(FAC2_e)    | move exponent & sign to FAC2
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | make sign compare = FAC1 sign
    eor.b    %d0,%a3@(FAC_sc)    | make sign compare (FAC1_s eor FAC2_s)
    bsr    labADD    | add FAC2 to FAC1
    bsr    labPFAC    | pack FAC1 into variable (Lvarpl)
labINCT:
    bsr    labGBYT    | scan memory
    cmpi.b    #0x2C,%d0    | compare with ","
    beq     lab17B8    | continue if "," (another variable to do)

    addq.w    #2,%sp    | else dump sign & exponent
    rts

labINCI:
    tst.b    %sp@(1)    | test sign
    bne.s    labDECI    | branch if DEC

    addq.l    #1,%a0@    | increment variable
    bra      labINCT    | go scan for more

labDECI:
    subq.l    #1,%a0@    | decrement variable
    bra      labINCT    | go scan for more


|************************************************************************************
|
| perform LET

labLET:
    bsr    labSVAR    | search for or create a variable
            | return the variable address in a0
    move.l    %a0,%a3@(Lvarpl)    | save variable address
    move.b    %a3@(Dtypef),%sp@-    | push var data type, 0x80=string, 0x40=integer,
            | 0x00=float
    move.L    #TK_EQUAL-0x100,%d0    | get = token
    bsr    labSCCA    | scan for CHR$(d0), else do syntax error/warm
            | start
    bsr    labEVEX    | evaluate expression
    move.b    %a3@(Dtypef),%d0    | copy expression data type
    move.b    %sp@+,%a3@(Dtypef)    | pop variable data type
    rol.b    #1,%d0    | set carry if expression type = string
    bsr    labCKTM    | type match check, set C for string
    beq    labPFAC    | if number pack FAC1 into variable Lvarpl & RET

| string LET

lab17D5:
    movea.l    %a3@(Lvarpl),%a2    | get pointer to variable
lab17D6:
    movea.l    %a3@(FAC1_m),%a0    | get descriptor pointer
    movea.l    %a0@,%a1    | get string pointer
    cmp.l    %a3@(Sstorl),%a1    | compare string memory start with string
            | pointer
    bcs.s    lab1811    | if it was in program memory assign the value
            | and exit

    cmpA.l    %a3@(Sfncl),%a0    | compare functions start with descriptor
            | pointer
    bcs.s    lab1811    | branch if >= (string is on stack)

            | string is variable0x make space and copy string
lab1810:
    moveq    #0,%d1    | clear length
    move.w    %a0@(4),%d1    | get string length
    movea.l    %a0@,%a0    | get string pointer
    bsr    lab20C9    | copy string
    movea.l    %a3@(FAC1_m),%a0    | get descriptor pointer back
            | clean stack & assign value to string variable
lab1811:
    cmpA.l    %a0,%a4    | is string on the descriptor stack
    bne.s    lab1813    | skip pop if not

    addq.w    #0x06,%a4    | else update stack pointer
lab1813:
    move.l    %a0@+,%a2@+    | save pointer to variable
    move.w    %a0@,%a2@    | save length to variable
rts_008:
    rts


|************************************************************************************
|
| perform GET

labGET:
    bsr    labSVAR    | search for or create a variable
            | return the variable address in a0
    move.l    %a0,%a3@(Lvarpl)    | save variable address as GET variable
    tst.b    %a3@(Dtypef)    | test data type, 0x80=string, 0x40=integer,
            | 0x00=float
    bmi      labGETS    | go get string character

            | was numeric get
    bsr    INGET    | get input byte
    bsr    lab1FD0    | convert d0 to unsigned byte in FAC1
    bra    labPFAC    | pack FAC1 into variable (Lvarpl) & return

labGETS:
    moveq    #0x00,%d1    | assume no byte
    move.l    %d1,%a0    | assume null string
    bsr    INGET    | get input byte
    bcc      labNoSt    | branch if no byte received

    moveq    #0x01,%d1    | string is single byte
    bsr    lab2115    | make string space d1 bytes long
            | return a0 = pointer, other registers unchanged

    move.b    %d0,%a0@    | save byte in string (byte IS string!)
labNoSt:
    bsr    labrtsT    | push string on descriptor stack
            | a0 = pointer, d1 = length

    bra      lab17D5    | do string LET & return


|************************************************************************************
|
| PRINT

lab1829:
    bsr    lab18C6    | print string from stack
lab182C:
    bsr    labGBYT    | scan memory

| perform PRINT

labPRINT:
    beq     labCRLF    | if nothing following just print CR/LF

lab1831:
    cmp.b    #TK_TAB,%d0    | compare with TAB( token
    beq     lab18A2    | go do TAB/SPC

    cmp.b    #TK_SPC,%d0    | compare with SPC( token
    beq     lab18A2    | go do TAB/SPC

    cmp.b    #',',%d0    | compare with ","
    beq     lab188B    | go do move to next TAB mark

    cmp.b    #'|',%d0    | compare with "|"
    beq    lab18BD    | if "|" continue with PRINT processing

    bsr    labEVEX    | evaluate expression
    tst.b    %a3@(Dtypef)    | test data type, 0x80=string, 0x40=integer,
            | 0x00=float
    bmi      lab1829    | branch if string

|* replace the two lines above with this code

|*    move.b    %a3@(Dtypef),%d0    | get data type flag, 0x80=string, 0x00=numeric
|*    bmi      lab1829    | branch if string

    bsr    lab2970    | convert FAC1 to string
    bsr    lab20AE    | print double-quote-terminated string to FAC1 stack

| dont check fit if terminal width byte is zero

    moveq    #0,%d0    | clear d0
    move.b    %a3@(TWidth),%d0    | get terminal width byte
    beq     lab185E    | skip check if zero

    sub.b    %a4@(7),%d0    | subtract string length
    sub.b    %a3@(TPos),%d0    | subtract terminal position
    bcc      lab185E    | branch if less than terminal width

    bsr      labCRLF    | else print CR/LF
lab185E:
    bsr      lab18C6    | print string from stack
    bra      lab182C    | always go continue processing line


|************************************************************************************
|
| CR/LF return to BASIC from BASIC input handler
| leaves a0 pointing to the buffer start

lab1866:
    move.b    #0x00,(%a0,%d1.w)    | null terminate input

| print CR/LF

labCRLF:
    moveq   #0x0D,%d0                   | load [CR]
    bsr     labPRNA                     | go print the character
    moveq   #0x0A,%d0                   | load [LF]
    bra     labPRNA                     | go print the character & return

lab188B:
    move.b    %a3@(TPos),%d2    | get terminal position
    cmp.b    %a3@(Iclim),%d2    | compare with input column limit
    bcs.s    lab1898    | branch if less than Iclim

    bsr      labCRLF    | else print CR/LF (next line)
    bra      lab18BD    | continue with PRINT processing

lab1898:
    sub.b    %a3@(TabSiz),%d2    | subtract TAB size
    bcc      lab1898    | loop if result was >= 0

    neg.b    %d2    | twos complement it
    bra      lab18B7    | print d2 spaces

            | do TAB/SPC
lab18A2:
    move.w    %d0,%sp@-    | save token
    bsr    labSGBY    | increment and get byte, result in d0 and Itemp
    move.w    %d0,%d2    | copy byte
    bsr    labGBYT    | get basic byte back
    cmp.b    #0x29,%d0    | is next character ")"
    bne    labSNER    | if not do syntax error, then warm start

    move.w    %sp@+,%d0    | get token back
    cmp.b    #TK_TAB,%d0    | was it TAB ?
    bne.s    lab18B7    | branch if not (was SPC)

            | calculate TAB offset
    sub.b    %a3@(TPos),%d2    | subtract terminal position
    bls.s    lab18BD    | branch if result was <= 0
            | cant TAB backwards or already there

            | print d2.b spaces
lab18B7:
    moveq    #0,%d0    | clear longword
    subq.b    #1,%d0    | make d0 = 0xFF
    and.l    %d0,%d2    | mask for byte only
    beq     lab18BD    | branch if zero

    moveq    #0x20,%d0    | load " "
    subq.b    #1,%d2    | adjust for dbf loop
lab18B8:
    bsr      labPRNA    | go print
    dbf    %d2,lab18B8    | decrement count and loop if not all done

            | continue with PRINT processing
lab18BD:
    bsr    labIGBY    | increment & scan memory
    bne    lab1831    | if byte continue executing PRINT

    rts    | exit if nothing more to print


|************************************************************************************
|
| print null terminated string from a0

lab18C3:
    bsr    lab20AE    | print terminated string to FAC1/stack

| print string from stack

lab18C6:
    bsr    lab22B6    | pop string off descriptor stack or from memory
            | returns with d0 = length, a0 = pointer
    beq     rts_009    | exit (rts) if null string

    move.w    %d0,%d1    | copy length & set Z flag
    subq.w    #1,%d1    | -1 for BF loop
lab18CD:
    move.b    %a0@+,%d0    | get byte from string
    bsr      labPRNA    | go print the character
    dbf    %d1,lab18CD    | decrement count and loop if not done yet

rts_009:
    rts


|************************************************************************************
|
| print "?" character

lab18E3:
    moveq    #0x3F,%d0    | load "?" character


|************************************************************************************
|
| print character in %d0, includes the null handler and infinite line length code
| changes no registers

labPRNA:

    move.l  %d1,%sp@-                   | save d1
    cmp.b   #0x20,%d0                   | compare with " "
    bcs.s   lab18F9                     | branch if less, non printing character

            | dont check fit if terminal width byte is zero
    move.b  %a3@(TWidth),%d1            | get terminal width
    bne.s   lab18F0                     | branch if not zero (not infinite length)

            | is "infinite line" so check TAB position
    move.b  %a3@(TPos),%d1              | get position
    sub.b   %a3@(TabSiz),%d1            | subtract TAB size
    bne.s   lab18F7                     | skip reset if different

    move.b  %d1,%a3@(TPos)              | else reset position

    bra     lab18F7                     | go print character

lab18F0:
    cmp.b   %a3@(TPos),%d1              | compare with terminal character position
    bne.s   lab18F7                     | branch if not at end of line

    move.l  %d0,%sp@-                   | save d0
    bsr     labCRLF                     | else print CR/LF
    move.l  %sp@+,%d0                   | restore d0
lab18F7:

    addq.b  #0x01,%a3@(TPos)            | increment terminal position
lab18F9:
    jsr     %a3@(V_OUTP)                | output byte via output vector
    cmp.b   #0x0D,%d0                   | compare with [CR]
    bne.s   lab188A                     | branch if not [CR]

            | else print nullct nulls after the [CR]
    moveq   #0x00,%d1                   | clear d1
    move.b  %a3@(Nullct),%d1            | get null count
    beq     lab1886                     | branch if no nulls

    moveq   #0x00,%d0                   | load [NULL]
lab1880:
    jsr     %a3@(V_OUTP)                | go print the character
    dbf     %d1,lab1880                 | decrement count and loop if not all done

    moveq   #0x0D,%d0                   | restore the character
lab1886:
    move.b  %d1,%a3@(TPos)              | clear terminal position
lab188A:
    move.l  %sp@+,%d1                   | restore d1
    rts


|************************************************************************************
|
| handle bad input data

lab1904:
    movea.l    %sp@+,%a5    | restore execute pointer
    tst.b    %a3@(Imode)    | test input mode flag, 0x00=INPUT, 0x98=READ
    bpl.s    lab1913    | branch if INPUT (go do redo)

    move.l    %a3@(Dlinel),%a3@(Clinel)    | save DATA line as current line
    bra    labTMER    | do type mismatch error, then warm start

            | mode was INPUT
lab1913:
    lea    %pc@(labREDO),%a0    | point to redo message
    bsr    lab18C3    | print null terminated string from memory
    movea.l    %a3@(Cpntrl),%a5    | save continue pointer as BASIC execute pointer
    rts


|************************************************************************************
|
| perform INPUT

labINPUT:
    bsr    labCKRN    | check not direct (back here if ok)
    cmp.b    #'"',%d0    | compare the next byte with open quote
    bne.s    lab1934    | if no prompt string just go get the input

    bsr    lab1BC1    | print "..." string
    moveq    #'|',%d0    | set the search character to "|"
    bsr    labSCCA    | scan for CHR$(d0), else do syntax error/warm
            | start
    bsr    lab18C6    | print string from Sutill/Sutilh
            | finished the prompt, now read the data
lab1934:
    bsr    labINLN    | print "? " and get BASIC input
            | return a0 pointing to the buffer start
    moveq    #0,%d0    | flag INPUT

| if you dont want a null response to INPUT to break the program then set the nobrk
| value at the top of this file to some non zero value

    .ifndef    nobrk

    bra      lab1953    | go handle the input

    .endif

| if you do want a null response to INPUT to break the program then leave the nobrk
| value at the top of this file set to zero

    .ifdef    nobrk

    tst.b    %a0@    | test first byte from buffer
    bne.s    lab1953    | branch if not null input

    bra    lab1647    | go do BREAK exit

    .endif


|************************************************************************************
|
| perform READ

labREAD:
    movea.l    %a3@(Dptrl),%a0    | get the DATA pointer
    moveq    #0x98-0x100,%d0    | flag READ
lab1953:
    move.b    %d0,%a3@(Imode)    | set input mode flag, 0x00=INPUT, 0x98=READ
    move.l    %a0,%a3@(Rdptrl)    | save READ pointer

            | READ or INPUT the next variable from list
lab195B:
    bsr    labSVAR    | search for or create a variable
            | return the variable address in a0
    move.l    %a0,%a3@(Lvarpl)    | save variable address as LET variable
    move.l    %a5,%sp@-    | save BASIC execute pointer
lab1961:
    movea.l    %a3@(Rdptrl),%a5    | set READ pointer as BASIC execute pointer
    bsr    labGBYT    | scan memory
    bne.s    lab1986    | if not null go get the value

            | the pointer was to a null entry
    tst.b    %a3@(Imode)    | test input mode flag, 0x00=INPUT, 0x98=READ
    bmi      lab19DD    | branch if READ (go find the next statement)

            | else the mode was INPUT so get more
    bsr    lab18E3    | print a "?" character
    bsr    labINLN    | print "? " and get BASIC input
            | return a0 pointing to the buffer start

| if you dont want a null response to INPUT to break the program then set the nobrk
| value at the top of this file to some non zero value

    .ifndef    nobrk

    move.l    %a0,%a3@(Rdptrl)    | save the READ pointer
    bra      lab1961    | go handle the input

    .endif

| if you do want a null response to INPUT to break the program then leave the nobrk
| value at the top of this file set to zero

    .ifdef    nobrk

    tst.b    %a0@    | test the first byte from the buffer
    bne.s    lab1984    | if not null input go handle it

    bra    lab1647    | else go do the BREAK exit

lab1984:
    movea.l    %a0,%a5    | set the execute pointer to the buffer
    subq.w    #1,%a5    | decrement the execute pointer

    .endif

lab1985:
    bsr    labIGBY    | increment & scan memory
lab1986:
    tst.b    %a3@(Dtypef)    | test data type, 0x80=string, 0x40=integer,
            | 0x00=float
    bpl.s    lab19B0    | branch if numeric

            | else get string
    move.b    %d0,%d2    | save search character
    cmp.b    #0x22,%d0    | was it double-quote ?
    beq     lab1999    | branch if so

    moveq    #':',%d2    | set new search character
    moveq    #',',%d0    | other search character is ","
    subq.w    #1,%a5    | decrement BASIC execute pointer
lab1999:
    addq.w    #1,%a5    | increment BASIC execute pointer
    move.b    %d0,%d3    | set second search character
    movea.l    %a5,%a0    | BASIC execute pointer is source

    bsr    lab20B4    | print d2/d3 terminated string to FAC1 stack
            | d2 = Srchc, d3 = Asrch, a0 is source
    movea.l    %a2,%a5    | copy end of string to BASIC execute pointer
    bsr    lab17D5    | go do string LET
    bra      lab19B6    | go check string terminator

            | get numeric INPUT
lab19B0:
    move.b    %a3@(Dtypef),%sp@-    | save variable data type
    bsr    lab2887    | get FAC1 from string
    move.b    %sp@+,%a3@(Dtypef)    | restore variable data type
    bsr    labPFAC    | pack FAC1 into (Lvarpl)
lab19B6:
    bsr    labGBYT    | scan memory
    beq     lab19C2    | branch if null (last entry)

    cmp.b    #',',%d0    | else compare with ","
    bne    lab1904    | if not "," go handle bad input data

    addq.w    #1,%a5    | else was "," so point to next chr
            | got good input data
lab19C2:
    move.l    %a5,%a3@(Rdptrl)    | save the read pointer for now
    movea.l    %sp@+,%a5    | restore the execute pointer
    bsr    labGBYT    | scan the memory
    beq     lab1A03    | if null go do extra ignored message

    pea    %pc@(lab195B)    | set return address
    bra    lab1C01    | scan for "," else do syntax error/warm start
            | then go INPUT next variable from list

            | find next DATA statement or do "Out of Data"
            | error
lab19DD:
    bsr    labSNBS    | scan for next BASIC statement ([:] or [EOL])
            | returns a0 as pointer to [:] or [EOL]
    movea.l    %a0,%a5    | add index, now = pointer to [EOL]/[EOS]
    addq.w    #1,%a5    | pointer to next character
    cmp.b    #':',%d0    | was it statement end?
    beq     lab19F6    | branch if [:]

            | was [EOL] so find next line

    move.w    %a5,%d1    | past pad byte(s)
    and.w    #1,%d1    | mask odd bit
    add.w    %d1,%a5    | add pointer
    move.l    %a5@+,%d2    | get next line pointer
    beq    labODER    | branch if end of program

    move.l    %a5@+,%a3@(Dlinel)    | save current DATA line
lab19F6:
    bsr    labGBYT    | scan memory
    cmp.b    #TK_DATA,%d0    | compare with "DATA" token
    beq    lab1985    | was "DATA" so go do next READ

    bra      lab19DD    | go find next statement if not "DATA"

| end of INPUT/READ routine

lab1A03:
    movea.l    %a3@(Rdptrl),%a0    | get temp READ pointer
    tst.b    %a3@(Imode)    | get input mode flag, 0x00=INPUT, 0x98=READ
    bpl.s    lab1A0E    | branch if INPUT

    move.l    %a0,%a3@(Dptrl)    | else save temp READ pointer as DATA pointer
    rts

            | we were getting INPUT
lab1A0E:
    tst.b    %a0@    | test next byte
    bne.s    lab1A1B    | error if not end of INPUT

    rts
            | user typed too much
lab1A1B:
    lea    %pc@(labIMSG),%a0    | point to extra ignored message
    bra    lab18C3    | print null terminated string from memory & rts


|************************************************************************************
|
| perform Next

labNext:
    bne.s    lab1A46    | branch if Next var

    addq.w    #4,%sp    | back past return address
    cmp.w    #TK_FOR,%sp@    | is FOR token on stack?
    bne    labNFER    | if not do Next without FOR err/warm start

    movea.l    %sp@(2),%a0    | get stacked FOR variable pointer
    bra      lab11BD    | branch always (no variable to search for)

| Next var

lab1A46:
    bsr    labGVAR    | get variable address in a0
    addq.w    #4,%sp    | back past return address
    move.w    #TK_FOR,%d0    | set for FOR token
    moveq    #0x1C,%d1    | set for FOR use size
    bra      lab11A6    | enter loop for next variable search

lab11A5:
    adda.l    %d1,%sp    | add FOR stack use size
lab11A6:
    cmp.w    %sp@,%d0    | is FOR token on stack?
    bne    labNFER    | if not found do Next without FOR error and
            | warm start

            | was FOR token
    cmpA.l    %sp@(2),%a0    | compare var pointer with stacked var pointer
    bne.s    lab11A5    | loop if no match found

lab11BD:
    move.w    %sp@(6),%a3@(FAC2_e)    | get STEP value exponent and sign
    move.l    %sp@(8),%a3@(FAC2_m)    | get STEP value mantissa

    move.b    %sp@(18),%a3@(Dtypef)    | restore FOR variable data type
    bsr    lab1C19    | check type and unpack %a0@

    move.b    %a3@(FAC2_s),%a3@(FAC_sc)    | save FAC2 sign as sign compare
    move.b    %a3@(FAC1_s),%d0    | get FAC1 sign
    eor.b    %d0,%a3@(FAC_sc)    | eor to create sign compare

    move.l    %a0,%a3@(Lvarpl)    | save variable pointer
    bsr    labADD    | add STEP value to FOR variable
    move.b    %sp@(18),%a3@(Dtypef)    | restore FOR variable data type (again)
    bsr    labPFAC    | pack FAC1 into FOR variable (Lvarpl)

    move.w    %sp@(12),%a3@(FAC2_e)    | get TO value exponent and sign
    move.l    %sp@(14),%a3@(FAC2_m)    | get TO value mantissa

    move.b    %a3@(FAC2_s),%a3@(FAC_sc)    | save FAC2 sign as sign compare
    move.b    %a3@(FAC1_s),%d0    | get FAC1 sign
    eor.b    %d0,%a3@(FAC_sc)    | eor to create sign compare

    bsr    lab27FA    | compare FAC1 with FAC2 (TO value)
            | returns d0=+1 if FAC1 > FAC2
            | returns d0= 0 if FAC1 = FAC2
            | returns d0=-1 if FAC1 < FAC2

    move.w    %sp@(6),%d1    | get STEP value exponent and sign
    eor.w    %d0,%d1    | eor compare result with STEP exponent and sign

    tst.b    %d0    | test for =
    beq     lab1A90    | branch if = (loop INcomplete)

    tst.b    %d1    | test result
    bpl.s    lab1A9B    | branch if > (loop complete)

            | loop back and do it all again
lab1A90:
    move.l    %sp@(20),%a3@(Clinel)    | reset current line
    move.l    %sp@(24),%a5    | reset BASIC execute pointer
    bra    lab15C2    | go do interpreter inner loop

            | loop complete so carry on
lab1A9B:
    adda.w    #28,%sp    | add 28 to dump FOR structure
    bsr    labGBYT    | scan memory
    cmp.b    #0x2C,%d0    | compare with ","
    bne    lab15C2    | if not "," go do interpreter inner loop

            | was "," so another Next variable to do
    bsr    labIGBY    | else increment & scan memory
    bsr    lab1A46    | do Next (var)


|************************************************************************************
|
| evaluate expression & check is numeric, else do type mismatch

labEVNM:
    bsr      labEVEX    | evaluate expression


|************************************************************************************
|
| check if source is numeric, else do type mismatch

labCTNM:
    cmp.w    %d0,%d0    | required type is numeric so clear carry


|************************************************************************************
|
| type match check, set C for string, clear C for numeric

labCKTM:
    btst.b    #7,%a3@(Dtypef)    | test data type flag, dont change carry
    bne.s    lab1ABA    | branch if data type is string

            | else data type was numeric
    bcs    labTMER    | if required type is string do type mismatch
            | error

    rts
            | data type was string, now check required type
lab1ABA:
    bcc    labTMER    | if required type is numeric do type mismatch
            | error
    rts


|************************************************************************************
|
| this routine evaluates any type of expression. first it pushes an end marker so
| it knows when the expression has been evaluated, this is a precedence value of zero.
| next the first value is evaluated, this can be an in line value, either numeric or
| string, a variable or array element of any type, a function or even an expression
| in parenthesis. this value is kept in FAC_1
| after the value is evaluated a test is made on the next BASIC program byte, if it
| is a comparrison operator i.e. "<", "=" or ">", then the corresponding bit is set
| in the comparison evaluation flag. this test loops until no more comparrison operators
| are found or more than one of any type is found. in the last case an error is generated

| evaluate expression

labEVEX:
    subq.w    #1,%a5    | decrement BASIC execute pointer
labEVEZ:
    moveq    #0,%d1    | clear precedence word
    move.b    %d1,%a3@(Dtypef)    | clear the data type, 0x80=string, 0x40=integer,
            | 0x00=float
    bra      lab1ACD    | enter loop

| get vector, set up operator then continue evaluation

lab1B43:        |
    lea    %pc@(labOPPT),%a0    | point to operator vector table
    move.w    2(%a0,%d1.w),%d0    | get vector offset
    pea    (%a0,%d0.w)    | push vector

    move.l    %a3@(FAC1_m),%sp@-    | push FAC1 mantissa
    move.w    %a3@(FAC1_e),%sp@-    | push sign and exponent
    move.b    %a3@(comp_f),%sp@-    | push comparison evaluation flag

    move.w    (%a0,%d1.w),%d1    | get precedence value
lab1ACD:
    move.w    %d1,%sp@-    | push precedence value
    bsr    labGVAL    | get value from line
    move.b    #0x00,%a3@(comp_f)    | clear compare function flag
lab1ADB:
    bsr    labGBYT    | scan memory
lab1ADE:
    sub.b    #TK_GT,%d0    | subtract token for > (lowest compare function)
    bcs.s    lab1AFA    | branch if < TK_GT

    cmp.b    #0x03,%d0    | compare with ">" to "<" tokens
    bcs.s    lab1AE0    | branch if <= TK_SGN (is compare function)

    tst.b    %a3@(comp_f)    | test compare function flag
    bne    lab1B2A    | branch if compare function

    bra    lab1B78    | go do functions

            | was token for > = or < (d0 = 0, 1 or 2)
lab1AE0:
    moveq    #1,%d1    | set to 0000 0001
    ASL.b    %d0,%d1    | 1 if >, 2 if =, 4 if <
    move.b    %a3@(comp_f),%d0    | copy old compare function flag
    eor.b    %d1,%a3@(comp_f)    | eor in this compare function bit
    cmp.b    %a3@(comp_f),%d0    | compare old with new compare function flag
    bcc    labSNER    | if new <= old comp_f do syntax error and warm
            | start, there was more than one <, = or >
    bsr    labIGBY    | increment & scan memory
    bra      lab1ADE    | go do next character

            | token is < ">" or > "<" tokens
lab1AFA:
    tst.b    %a3@(comp_f)    | test compare function flag
    bne.s    lab1B2A    | branch if compare function

            | was < TK_GT so is operator or lower
    add.b    #(TK_GT-TK_PLUS),%d0    | add # of operators (+ - | / ^ and OR eor)
    bcc      lab1B78    | branch if < + operator

    bne.s    lab1B0B    | branch if not + token

    tst.b    %a3@(Dtypef)    | test data type, 0x80=string, 0x40=integer,
            | 0x00=float
    bmi    lab224D    | type is string & token was +

lab1B0B:
    moveq    #0,%d1    | clear longword
    add.b    %d0,%d0    | |2
    add.b    %d0,%d0    | |4
    move.b    %d0,%d1    | copy to index
lab1B13:
    move.w    %sp@+,%d0    | pull previous precedence
    lea    %pc@(labOPPT),%a0    | set pointer to operator table
    cmp.w    (%a0,%d1.w),%d0    | compare with this opperator precedence
    bcc      lab1B7D    | branch if previous precedence (d0) >=

    bsr    labCTNM    | check if source is numeric, else type mismatch
lab1B1C:
    move.w    %d0,%sp@-    | save precedence
lab1B1D:
    bsr    lab1B43    | get vector, set-up operator and continue
            | evaluation
    move.w    %sp@+,%d0    | restore precedence
    move.l    %a3@(prstk),%d1    | get stacked function pointer
    bpl.s    lab1B3C    | branch if stacked values

    move.w    %d0,%d0    | copy precedence (set flags)
    beq     lab1B7B    | exit if done

    bra      lab1B86    | else pop FAC2 & return (do function)

            | was compare function (< = >)
lab1B2A:
    move.b    %a3@(Dtypef),%d0    | get data type flag
    move.b    %a3@(comp_f),%d1    | get compare function flag
    add.b    %d0,%d0    | string bit flag into X bit
    addX.b    %d1,%d1    | shift compare function flag

    move.b    #0,%a3@(Dtypef)    | clear data type flag, 0x00=float
    move.b    %d1,%a3@(comp_f)    | save new compare function flag
    subq.w    #1,%a5    | decrement BASIC execute pointer
    moveq    #(TK_LT-TK_PLUS)*4,%d1    | set offset to last operator entry
    bra      lab1B13    | branch always

lab1B3C:
    lea    %pc@(labOPPT),%a0    | point to function vector table
    cmp.w    (%a0,%d1.w),%d0    | compare with this opperator precedence
    bcc      lab1B86    | branch if d0 >=, pop FAC2 & return

    bra      lab1B1C    | branch always

| do functions

lab1B78:
    moveq    #-1,%d1    | flag all done
    move.w    %sp@+,%d0    | pull precedence word
lab1B7B:
    beq     lab1B9D    | exit if done

lab1B7D:
    cmp.w    #0x64,%d0    | compare previous precedence with 0x64
    beq     lab1B84    | branch if was 0x64 (< function can be string)

    bsr    labCTNM    | check if source is numeric, else type mismatch
lab1B84:
    move.l    %d1,%a3@(prstk)    | save current operator index

            | pop FAC2 & return
lab1B86:
    move.b    %sp@+,%d0    | pop comparison evaluation flag
    move.b    %d0,%d1    | copy comparison evaluation flag
    lsr.b    #1,%d0    | shift out comparison evaluation lowest bit
    move.b    %d0,%a3@(Cflag)    | save comparison evaluation flag
    move.w    %sp@+,%a3@(FAC2_e)    | pop exponent and sign
    move.l    %sp@+,%a3@(FAC2_m)    | pop mantissa
    move.b    %a3@(FAC2_s),%a3@(FAC_sc)    | copy FAC2 sign
    move.b    %a3@(FAC1_s),%d0    | get FAC1 sign
    eor.b    %d0,%a3@(FAC_sc)    | eor FAC1 sign and set sign compare

    lsr.b    #1,%d1    | type bit into X and C
    rts

lab1B9D:
    move.b    %a3@(FAC1_e),%d0    | get FAC1 exponent
    rts


|************************************************************************************
|
| get a value from the BASIC line

labGVAL:
    bsr      labIGBY    | increment & scan memory
    bcs    lab2887    | if numeric get FAC1 from string & return

    tst.b    %d0    | test byte
    bmi    lab1BD0    | if -ve go test token values

            | else it is either a string, number, variable
            | or (<expr>)
    cmp.b    #'$',%d0    | compare with "$"
    beq    lab2887    | if "0x" get hex number from string & return

    cmp.b    #'%',%d0    | else compare with "%"
    beq    lab2887    | if "%" get binary number from string & return

    cmp.b    #0x2E,%d0    | compare with "."
    beq    lab2887    | if so get FAC1 from string and return
            | (e.g. .123)

            | wasnt a number so ...
    cmp.b    #0x22,%d0    | compare with double-quote
    bne.s    lab1BF3    | if not open quote it must be a variable or
            | open bracket

            | was open quote so get the enclosed string

| print "..." string to string stack

lab1BC1:
    move.b    %a5@+,%d0    | increment BASIC execute pointer (past double-quote)
            | fastest/shortest method
    movea.l    %a5,%a0    | copy basic execute pointer (string start)
    bsr    lab20AE    | print double-quote-terminated string to stack
    movea.l    %a2,%a5    | restore BASIC execute pointer from temp
    rts

| get value from line .. continued
            | wasnt any sort of number so ...
lab1BF3:
    cmp.b    #'(',%d0    | compare with "("
    bne.s    lab1C18    | if not "(" get (var) and return value in FAC1
            | and 0x flag


|************************************************************************************
|
| evaluate expression within parentheses

lab1BF7:
    bsr    labEVEZ    | evaluate expression (no decrement)


|************************************************************************************
|
| all the 'scan for' routines return the character after the sought character

| scan for ")", else do syntax error, then warm start

lab1BFB:
    moveq    #0x29,%d0    | load d0 with ")"
    bra      labSCCA


|************************************************************************************
|
| scan for "," and get byte, else do Syntax error then warm start

labSCGB:
    pea    %pc@(labGTBY)    | return address is to get byte parameter


|************************************************************************************
|
| scan for ",", else do syntax error, then warm start

lab1C01:
    moveq    #0x2C,%d0    | load d0 with ","


|************************************************************************************
|
| scan for CHR$(d0) , else do syntax error, then warm start

labSCCA:
    cmp.b    %a5@+,%d0    | check next byte is = d0
    beq     labGBYT    | if so go get next

    bra    labSNER    | else do syntax error/warm start


|************************************************************************************
|
| BASIC increment and scan memory routine

labIGBY:
    move.b    %a5@+,%d0    | get byte & increment pointer

| scan memory routine, exit with Cb = 1 if numeric character
| also skips any spaces encountered

labGBYT:
    move.b    %a5@,%d0    | get byte

    cmp.b    #0x20,%d0    | compare with " "
    beq     labIGBY    | if " " go do next

| test current BASIC byte, exit with Cb = 1 if numeric character

    cmp.b    #TK_ELSE,%d0    | compare with the token for ELSE
    bcc      rts_001    | exit if >= (not numeric, carry clear)

    cmp.b    #0x3A,%d0    | compare with ":"
    bcc      rts_001    | exit if >= (not numeric, carry clear)

    move.b    #0xd0,%d6    | set -"0"
    add.b    %d6,%d0    | add -"0"
    sub.b    %d6,%d0    | subtract -"0"
rts_001:    | carry set if byte = "0"-"9"
    rts


|************************************************************************************
|
| set-up for - operator

lab1C11:
    bsr    labCTNM    | check if source is numeric, else type mismatch
    moveq    #(TK_GT-TK_PLUS)*4,%d1    | set offset from base to - operator
lab1C13:
    lea    %sp@(4),%sp    | dump GVAL return address
    bra    lab1B1D    | continue evaluating expression


|************************************************************************************
|
| variable name set-up
| get (var), return value in FAC_1 & data type flag

lab1C18:
    bsr    labGVAR    | get variable address in a0

| if you want a non existant variable to return a null value then set the novar
| value at the top of this file to some non zero value

    .ifndef    novar

    bne.s    lab1C19    | if it exists return it

    lea.l    %pc@(lab1D96),%a0    | else return a null descriptor/pointer

    .endif

| return existing variable value

lab1C19:
    tst.b    %a3@(Dtypef)    | test data type, 0x80=string, 0x40=integer,
            | 0x00=float
    beq    labUFAC    | if float unpack memory %a0@ into FAC1 and
            | return

    bpl.s    lab1C1A    | if integer unpack memory %a0@ into FAC1
            | and return

    move.l    %a0,%a3@(FAC1_m)    | else save descriptor pointer in FAC1
    rts

lab1C1A:
    move.l    %a0@,%d0    | get integer value
    bra    labAYFC    | convert d0 to signed longword in FAC1 & return


|************************************************************************************
|
| get value from line .. continued
| do tokens

lab1BD0:
    cmp.b    #TK_MINUS,%d0    | compare with token for -
    beq     lab1C11    | branch if - token (do set-up for - operator)

            | wasnt -123 so ...
    cmp.b    #TK_PLUS,%d0    | compare with token for +
    beq    labGVAL    | branch if + token (+n = n so ignore leading +)

    cmp.b    #TK_NOT,%d0    | compare with token for NOT
    bne.s    lab1BE7    | branch if not token for NOT

            | was NOT token
    move.w    #(TK_EQUAL-TK_PLUS)*4,%d1    | offset to NOT function
    bra      lab1C13    | do set-up for function then execute

            | wasnt +, - or NOT so ...
lab1BE7:
    cmp.b    #TK_FN,%d0    | compare with token for FN
    beq    lab201E    | if FN go evaluate FNx

            | was not +, -, NOT or FN so ...
    sub.b    #TK_SGN,%d0    | compare with token for SGN & normalise
    bcs    labSNER    | if < SGN token then do syntax error

| get value from line .. continued
| only functions left so set up function references

| new for V2.0+ this replaces a lot of IF .. THEN .. ELSEIF .. THEN .. that was needed
| to process function calls. now the function vector is computed and pushed on the stack
| and the preprocess offset is read. if the preprocess offset is non zero then the vector
| is calculated and the routine called, if not this routine just does rts. whichever
| happens the rts at the end of this routine, or the preprocess routine calls, the
| function code

| this also removes some less than elegant code that was used to bypass type checking
| for functions that returned strings

    and.w    #0x7F,%d0    | mask byte
    add.w    %d0,%d0    | |2 (2 bytes per function offset)

    lea    %pc@(labFTBL),%a0    | pointer to functions vector table
    move.w    (%a0,%d0.w),%d1    | get function vector offset
    pea    (%a0,%d1.w)    | push function vector

    lea    %pc@(labFTPP),%a0    | pointer to functions preprocess vector table
    move.w    (%a0,%d0.w),%d0    | get function preprocess vector offset
    beq     lab1C2A    | no preprocess vector so go do function

    lea    (%a0,%d0.w),%a0    | get function preprocess vector
    jmp    %a0@    | go do preprocess routine then function


|************************************************************************************
|
| process string expression in parenthesis

labPPFS:
    bsr    lab1BF7    | process expression in parenthesis
    tst.b    %a3@(Dtypef)    | test data type
    bpl    labTMER    | if numeric do Type missmatch Error/warm start

lab1C2A:
    rts    | else do function


|************************************************************************************
|
| process numeric expression in parenthesis

labPPFN:
    bsr    lab1BF7    | process expression in parenthesis
    tst.b    %a3@(Dtypef)    | test data type
    bmi    labTMER    | if string do Type missmatch Error/warm start

    rts    | else do function


|************************************************************************************
|
| set numeric data type and increment BASIC execute pointer

labPPBI:
    move.b    #0x00,%a3@(Dtypef)    | clear data type flag, 0x00=float
    move.b    %a5@+,%d0    | get next BASIC byte
    rts    | do function


|************************************************************************************
|
| process string for LEFT$, RIGHT$ or MID$

labLRMS:
    bsr    labEVEZ    | evaluate (should be string) expression
    tst.b    %a3@(Dtypef)    | test data type flag
    bpl    labTMER    | if type is not string do type mismatch error

    move.b    %a5@+,%d2    | get BASIC byte
    cmp.b    #',',%d2    | compare with comma
    bne    labSNER    | if not "," go do syntax error/warm start

    move.l    %a3@(FAC1_m),%sp@-    | save descriptor pointer
    bsr    labGTWO    | get word parameter, result in d0 and Itemp
    movea.l    %sp@+,%a0    | restore descriptor pointer
    rts    | do function


|************************************************************************************
|
| process numeric expression(s) for BIN$ or HEX$

labBHSS:
    bsr    labEVEZ    | evaluate expression (no decrement)
    tst.b    %a3@(Dtypef)    | test data type
    bmi    labTMER    | if string do Type missmatch Error/warm start

    bsr    lab2831    | convert FAC1 floating to fixed
            | result in d0 and Itemp
    moveq    #0,%d1    | set default to no leading "0"s
    move.b    %a5@+,%d2    | get BASIC byte
    cmp.b    #',',%d2    | compare with comma
    bne.s    labBHCB    | if not "," go check close bracket

    move.l    %d0,%sp@-    | copy number to stack
    bsr    labGTBY    | get byte value
    move.l    %d0,%d1    | copy leading 0s #
    move.l    %sp@+,%d0    | restore number from stack
    move.b    %a5@+,%d2    | get BASIC byte
labBHCB:
    cmp.b    #')',%d2    | compare with close bracket
    bne    labSNER    | if not ")" do Syntax Error/warm start

    rts    | go do function


|************************************************************************************
|
| perform EOR

labEOR:
    bsr      GetFirst    | get two values for OR, and or eor
            | first in %d0, and Itemp, second in d2
    eor.l    %d2,%d0    | eor values
    bra    labAYFC    | convert d0 to signed longword in FAC1 & RET


|************************************************************************************
|
| perform OR

labOR:
    bsr      GetFirst    | get two values for OR, and or eor
            | first in %d0, and Itemp, second in d2
    OR.l    %d2,%d0    | do OR
    bra    labAYFC    | convert d0 to signed longword in FAC1 & RET


|************************************************************************************
|
| perform AND

labAND:
    bsr      GetFirst    | get two values for OR, and or eor
            | first in %d0, and Itemp, second in d2
    and.l    %d2,%d0    | do and
    bra    labAYFC    | convert d0 to signed longword in FAC1 & RET


|************************************************************************************
|
| get two values for OR, and, eor
| first in %d0, second in d2

GetFirst:
    bsr    labEVIR    | evaluate integer expression (no sign check)
            | result in d0 and Itemp
    move.l    %d0,%d2    | copy second value
    bsr    lab279B    | copy FAC2 to FAC1, get first value in
            | expression
    bra    labEVIR    | evaluate integer expression (no sign check)
            | result in d0 and Itemp & return


|************************************************************************************
|
| perform NOT

labEQUAL:
    bsr    labEVIR    | evaluate integer expression (no sign check)
            | result in d0 and Itemp
    NOT.l    %d0    | bitwise invert
    bra    labAYFC    | convert d0 to signed longword in FAC1 & RET


|************************************************************************************
|
| perform comparisons
| do < compare

labLTHAN:
    bsr    labCKTM    | type match check, set C for string
    bcs.s    lab1CAE    | branch if string

            | do numeric < compare
    bsr    lab27FA    | compare FAC1 with FAC2
            | returns d0=+1 if FAC1 > FAC2
            | returns d0= 0 if FAC1 = FAC2
            | returns d0=-1 if FAC1 < FAC2
    bra      lab1CF2    | process result

            | do string < compare
lab1CAE:
    move.b    #0x00,%a3@(Dtypef)    | clear data type, 0x80=string, 0x40=integer,
            | 0x00=float
    bsr    lab22B6    | pop string off descriptor stack, or from top
            | of string space returns d0 = length,
            | a0 = pointer
    movea.l    %a0,%a1    | copy string 2 pointer
    move.l    %d0,%d1    | copy string 2 length
    movea.l    %a3@(FAC2_m),%a0    | get string 1 descriptor pointer
    bsr    lab22BA    | pop %a0@ descriptor, returns with ..
            | d0 = length, a0 = pointer
    move.l    %d0,%d2    | copy length
    bne.s    lab1CB5    | branch if not null string

    tst.l    %d1    | test if string 2 is null also
    beq     lab1CF2    | if so do string 1 = string 2

lab1CB5:
    sub.l    %d1,%d2    | subtract string 2 length
    beq     lab1CD5    | branch if strings = length

    bcs.s    lab1CD4    | branch if string 1 < string 2

    moveq    #-1,%d0    | set for string 1 > string 2
    bra      lab1CD6    | go do character comapare

lab1CD4:
    move.l    %d0,%d1    | string 1 length is compare length
    moveq    #1,%d0    | and set for string 1 < string 2
    bra      lab1CD6    | go do character comapare

lab1CD5:
    move.l    %d2,%d0    | set for string 1 = string 2
lab1CD6:
    subq.l    #1,%d1    | adjust length for DBcc loop

            | d1 is length to compare, d0 is <=> for length
            | a0 is string 1 pointer, a1 is string 2 pointer
lab1CE6:
    cmpM.b    %a0@+,%a1@+    | compare string bytes (1 with 2)
    Dbne    %d1,lab1CE6    | loop if same and not end yet

    beq     lab1CF2    | if = to here, then go use length compare

    bcc      lab1CDB    | else branch if string 1 > string 2

    moveq    #-1,%d0    | else set for string 1 < string 2
    bra      lab1CF2    | go set result

lab1CDB:
    moveq    #1,%d0    | and set for string 1 > string 2

lab1CF2:
    addq.b    #1,%d0    | make result 0, 1 or 2
    move.b    %d0,%d1    | copy to d1
    moveq    #1,%d0    | set d0 longword
    rol.b    %d1,%d0    | make 1, 2 or 4 (result = flag bit)
    and.b    %a3@(Cflag),%d0    | and with comparison evaluation flag
    beq    lab27DB    | exit if not a wanted result (i.e. false)

    moveq    #-1,%d0    | else set -1 (true)
    bra    lab27DB    | save d0 as integer & return


lab1CFE:
    bsr    lab1C01    | scan for ",", else do syntax error/warm start


|************************************************************************************
|
| perform DIM

labDIM:
    moveq    #-1,%d1    | set "DIM" flag
    bsr      lab1D10    | search for or dimension a variable
    bsr    labGBYT    | scan memory
    bne.s    lab1CFE    | loop and scan for "," if not null

    rts


|************************************************************************************
|
| perform << (left shift)

labLSHIFT:
    bsr      GetPair    | get an integer and byte pair
            | byte is in %d2, integer is in d0 and Itemp
    beq     NoShift    | branch if byte zero

    cmp.b    #0x20,%d2    | compare bit count with 32d
    bcc      TooBig    | branch if >=

    ASL.l    %d2,%d0    | shift longword
NoShift:
    bra    labAYFC    | convert d0 to signed longword in FAC1 & RET


|************************************************************************************
|
| perform >> (right shift)

labRSHIFT:
    bsr      GetPair    | get an integer and byte pair
            | byte is in %d2, integer is in d0 and Itemp
    beq     NoShift    | branch if byte zero

    cmp.b    #0x20,%d2    | compare bit count with 32d
    bcs.s    Not2Big    | branch if >= (return shift)

    tst.l    %d0    | test sign bit
    bpl.s    TooBig    | branch if +ve

    moveq    #-1,%d0    | set longword
    bra    labAYFC    | convert d0 to longword in FAC1 & RET

Not2Big:
    ASR.l    %d2,%d0    | shift longword
    bra    labAYFC    | convert d0 to longword in FAC1 & RET

TooBig:
    moveq    #0,%d0    | clear longword
    bra    labAYFC    | convert d0 to longword in FAC1 & RET


|************************************************************************************
|
| get an integer and byte pair
| byte is in %d2, integer is in d0 and Itemp

GetPair:
    bsr    labEVBY    | evaluate byte expression, result in d0 and
            | Itemp
    move.b    %d0,%d2    | save it
    bsr    lab279B    | copy FAC2 to FAC1, get first value in
            | expression
    bsr    labEVIR    | evaluate integer expression (no sign check)
            | result in d0 and Itemp
    tst.b    %d2    | test byte value
    rts


|************************************************************************************
|
| check alpha, return C=0 if<"A" or >"Z" or <"a" to "z">

labCASC:
    cmp.b    #0x61,%d0    | compare with "a"
    bcc      lab1D83    | if >="a" go check =<"z"


|************************************************************************************
|
| check alpha upper case, return C=0 if<"A" or >"Z"

labCAUC:
    cmp.b    #0x41,%d0    | compare with "A"
    bcc      lab1D8A    | if >="A" go check =<"Z"

    OR    %d0,%d0    | make C=0
    rts

lab1D8A:
    cmp.b    #0x5B,%d0    | compare with "Z"+1
            | carry set if byte<="Z"
    rts

lab1D83:
    cmp.b    #0x7B,%d0    | compare with "z"+1
            | carry set if byte<="z"
    rts


|************************************************************************************
|
| search for or create variable. this is used to automatically create a variable if
| it is not found. any routines that need to create the variable call labGVAR via
| this point and error generation is supressed and the variable will be created
|
| return pointer to variable in Cvaral and a0
| set data type to variable type

labSVAR:
    bsr      labGVAR    | search for variable
labFVAR:
    rts


|************************************************************************************
|
| search for variable. if this routine is called from anywhere but the above call and
| the variable searched for does not exist then an error will be returned
|
| DIM flag is in d1.b
| return pointer to variable in Cvaral and a0
| set data type to variable type

labGVAR:
    moveq    #0x00,%d1    | set DIM flag = 0x00
    bsr    labGBYT    | scan memory (1st character)
lab1D10:
    move.b    %d1,%a3@(Defdim)    | save DIM flag

| search for FN name entry point

lab1D12:
    bsr      labCASC    | check byte, return C=0 if<"A" or >"Z"
    bcc    labSNER    | if not, syntax error then warm start

            | it is a variable name so ...
    moveq    #0x0,%d1    | set index for name byte
    lea    %a3@(Varname),%a0    | pointer to variable name
    move.l    %d1,%a0@    | clear the variable name
    move.b    %d1,%a3@(Dtypef)    | clear the data type, 0x80=string, 0x40=integer,
            | 0x00=float

lab1D2D:
    cmp.w    #0x04,%d1    | done all significant characters?
    bcc      lab1D2E    | if so go ignore any more

    move.b    %d0,(%a0,%d1.w)    | save the character
    addq.w    #1,%d1    | increment index
lab1D2E:
    bsr    labIGBY    | increment & scan memory (next character)
    bcs.s    lab1D2D    | branch if character = "0"-"9" (ok)

            | character was not "0" to "9" so ...
    bsr      labCASC    | check byte, return C=0 if<"A" or >"Z"
    bcs.s    lab1D2D    | branch if = "A"-"Z" (ok)

            | check if string variable
    cmp.b    #'$',%d0    | compare with "0x"
    bne.s    lab1D44    | branch if not string

            | type is string
    OR.b    #0x80,%a3@(Varname+1)    | set top bit of 2nd character, indicate string
    bsr    labIGBY    | increment & scan memory
    bra      lab1D45    | skip integer check

            | check if integer variable
lab1D44:
    cmp.b    #'&',%d0    | compare with "&"
    bne.s    lab1D45    | branch if not integer

            | type is integer
    OR.b    #0x80,%a3@(Varname+2)    | set top bit of 3rd character, indicate integer
    bsr    labIGBY    | increment & scan memory

| after we have determined the variable type we need to determine
| if it is an array of type

            | gets here with character after var name in d0
lab1D45:
    tst.b    %a3@(Sufnxf)    | test function name flag
    beq     lab1D48    | if not FN or FN variable continue

    bpl.s    lab1D49    | if FN variable go find or create it

            | else was FN name
    move.l    %a3@(Varname),%d0    | get whole function name
    moveq    #8,%d1    | set step to next function size -4
    lea    %a3@(Sfncl),%a0    | get pointer to start of functions
    bra      lab1D4B    | go find function

lab1D48:
    sub.b    #'(',%d0    | subtract "("
    beq    lab1E17    | if "(" go find, or make, array

| either find or create var
| var name (1st four characters only!) is in Varname

            | variable name was not var( .. so look for
            | plain variable
lab1D49:
    move.l    %a3@(Varname),%d0    | get whole variable name
lab1D4A:
    moveq    #4,%d1    | set step to next variable size -4
    lea    %a3@(Svarl),%a0    | get pointer to start of variables

    btst.l    #23,%d0    | test if string name
    beq     lab1D4B    | branch if not

    addq.w    #2,%d1    | 6 bytes per string entry
    addq.w    #(Sstrl-Svarl),%a0    | move to string area

lab1D4B:
    movea.l    %a0@(4),%a1    | get end address
    movea.l    %a0@,%a0    | get start address
    bra      lab1D5E    | enter loop at exit check

lab1D5D:
    cmp.l    %a0@+,%d0    | compare this variable with name
    beq     lab1DD7    | branch if match (found var)

    adda.l    %d1,%a0    | add offset to next variable
lab1D5E:
    cmpA.l    %a1,%a0    | compare address with variable space end
    bne.s    lab1D5D    | if not end go check next

    tst.b    %a3@(Sufnxf)    | is it a function or function variable
    bne.s    lab1D94    | if was go do DEF or function variable

            | reached end of variable mem without match
            | ... so create new variable, possibly

    lea    %pc@(labFVAR),%a2    | get the address of the create if does not
            | exist call to labGVAR
    cmpA.l    %sp@,%a2    | compare the return address with expected
    bne    labUVER    | if not create go do error or return null

| this will only branch if the call to labGVAR was not from labSVAR

lab1D94:
    btst.b    #0,%a3@(Sufnxf)    | test function search flag
    bne    labUFER    | if not doing DEF then go do undefined
            | function error

            | else create new variable/function
lab1D98:
    movea.l    %a3@(Earryl),%a2    | get end of block to move
    move.l    %a2,%d2    | copy end of block to move
    sub.l    %a1,%d2    | calculate block to move size

    movea.l    %a2,%a0    | copy end of block to move
    addq.l    #4,%d1    | space for one variable/function + name
    adda.l    %d1,%a2    | add space for one variable/function
    move.l    %a2,%a3@(Earryl)    | set new array mem end
    lsr.l    #1,%d2    | /2 for word copy
    beq     lab1DAF    | skip move if zero length block

    subq.l    #1,%d2    | -1 for DFB loop
    swap    %d2    | swap high word to low word
lab1DAC:
    swap    %d2    | swap high word to low word
lab1DAE:
    move.w    %a0@-,%a2@-    | copy word
    dbf    %d2,lab1DAE    | loop until done

    swap    %d2    | swap high word to low word
    dbf    %d2,lab1DAC    | decrement high count and loop until done

| get here after creating either a function, variable or string
| if function set variables start, string start, array start
| if variable set string start, array start
| if string set array start

lab1DAF:
    tst.b    %a3@(Sufnxf)    | was it function
    bmi      lab1DB0    | branch if was FN

    btst.l    #23,%d0    | was it string
    bne.s    lab1DB2    | branch if string

    bra      lab1DB1    | branch if was plain variable

lab1DB0:
    add.l    %d1,%a3@(Svarl)    | set new variable memory start
lab1DB1:
    add.l    %d1,%a3@(Sstrl)    | set new start of strings
lab1DB2:
    add.l    %d1,%a3@(Sarryl)    | set new array memory start
    move.l    %d0,%a0@+    | save variable/function name
    move.l    #0x00,%a0@    | initialise variable
    btst.l    #23,%d0    | was it string
    beq     lab1DD7    | branch if not string

    move.w    #0x00,%a0@(4)    | else initialise string length

            | found a match for var ((Vrschl) = ptr)
lab1DD7:
    move.l    %d0,%d1    | ........ 0x....... &....... ........
    add.l    %d1,%d1    | .......0x .......& ........ .......0
    swap    %d1    | ........ .......0 .......0x .......&
    ror.b    #1,%d1    | ........ .......0 .......0x &.......
    lsr.w    #1,%d1    | ........ .......0 0....... 0x&.....≠.
    and.b    #0xC0,%d1    | mask the type bits
    move.b    %d1,%a3@(Dtypef)    | save the data type

    move.b    #0x00,%a3@(Sufnxf)    | clear FN flag byte

| if you want a non existant variable to return a null value then set the novar
| value at the top of this file to some non zero value

    .ifndef    novar

    moveq    #-1,%d0    | return variable found

    .endif

    rts


|************************************************************************************
|
| set-up array pointer, %d0, to first element in array
| set d0 to %a0@+2*(Dimcnt)+0x0A

lab1DE6:
    moveq    #5,%d0    | set d0 to 5 (*2 = 10, later)
    add.b    %a3@(Dimcnt),%d0    | add # of dimensions (1, 2 or 3)
    add.l    %d0,%d0    | |2 (bytes per dimension size)
    add.l    %a0,%d0    | add array start pointer
    rts


|************************************************************************************
|
| evaluate unsigned integer expression

labEVIN:
    bsr    labIGBY    | increment & scan memory
    bsr    labEVNM    | evaluate expression & check is numeric,
            | else do type mismatch


|************************************************************************************
|
| evaluate positive integer expression, result in d0 and Itemp

labEVPI:
    tst.b    %a3@(FAC1_s)    | test FAC1 sign (b7)
    bmi    labFCER    | do function call error if -ve


|************************************************************************************
|
| evaluate integer expression, no sign check
| result in d0 and Itemp, exit with flags set correctly

labEVIR:
    cmpi.b    #0xa0,%a3@(FAC1_e)    | compare exponent with exponent = 2^32 (n>2^31)
    bcs    lab2831    | convert FAC1 floating to fixed
            | result in d0 and Itemp
    bne    labFCER    | if > do function call error, then warm start

    tst.b    %a3@(FAC1_s)    | test sign of FAC1
    bpl    lab2831    | if +ve then ok

    move.l    %a3@(FAC1_m),%d0    | get mantissa
    neg.l    %d0    | do -d0
    BVC    labFCER    | if not 0x80000000 do FC error, then warm start

    move.l    %d0,%a3@(Itemp)    | else just set it
    rts


|************************************************************************************
|
| find or make array

lab1E17:
    move.w    %a3@(Defdim),%sp@-    | get DIM flag and data type flag (word in mem)
    moveq    #0,%d1    | clear dimensions count

| now get the array dimension(s) and stack it (them) before the data type and DIM flag

lab1E1F:
    move.w    %d1,%sp@-    | save dimensions count
    move.l    %a3@(Varname),%sp@-    | save variable name
    bsr      labEVIN    | evaluate integer expression

    swap    %d0    | swap high word to low word
    tst.w    %d0    | test swapped high word
    bne    labABER    | if too big do array bounds error

    move.l    %sp@+,%a3@(Varname)    | restore variable name
    move.w    %sp@+,%d1    | restore dimensions count
    move.w    %sp@+,%d0    | restore DIM and data type flags
    move.w    %a3@(Itemp+2),%sp@-    | stack this dimension size
    move.w    %d0,%sp@-    | save DIM and data type flags
    addq.w    #1,%d1    | increment dimensions count
    bsr    labGBYT    | scan memory
    cmp.b    #0x2C,%d0    | compare with ","
    beq     lab1E1F    | if found go do next dimension

    move.b    %d1,%a3@(Dimcnt)    | store dimensions count
    bsr    lab1BFB    | scan for ")", else do syntax error/warm start
    move.w    %sp@+,%a3@(Defdim)    | restore DIM and data type flags (word in mem)
    movea.l    %a3@(Sarryl),%a0    | get array mem start

| now check to see if we are at the end of array memory (we would be if there were
| no arrays).

lab1E5C:
    move.l    %a0,%a3@(Astrtl)    | save as array start pointer
    cmpA.l    %a3@(Earryl),%a0    | compare with array mem end
    beq     lab1EA1    | go build array if not found

            | search for array
    move.l    %a0@,%d0    | get this array name
    cmp.l    %a3@(Varname),%d0    | compare with array name
    beq     lab1E8D    | array found so branch

            | no match
    movea.l    %a0@(4),%a0    | get this array size
    adda.l    %a3@(Astrtl),%a0    | add to array start pointer
    bra      lab1E5C    | go check next array

            | found array, are we trying to dimension it?
lab1E8D:
    tst.b    %a3@(Defdim)    | are we trying to dimension it?
    bne    labDDER    | if so do double dimension error/warm start

| found the array and we are not dimensioning it so we must find an element in it

    bsr    lab1DE6    | set data pointer, %d0, to the first element
            | in the array
    addq.w    #8,%a0    | index to dimension count
    move.w    %a0@+,%d0    | get no of dimensions
    cmp.b    %a3@(Dimcnt),%d0    | compare with dimensions count
    beq    lab1F28    | found array so go get element

    bra    labWDER    | else wrong so do "Wrong dimensions" error

            | array not found, so possibly build it
lab1EA1:
    tst.b    %a3@(Defdim)    | test the default DIM flag
    beq    labUDER    | if default flag is clear then we are not
            | explicitly dimensioning an array so go
            | do an "Undimensioned array" error

    bsr    lab1DE6    | set data pointer, %d0, to the first element
            | in the array
    move.l    %a3@(Varname),%d0    | get array name
    move.l    %d0,%a0@+    | save array name
    moveq    #4,%d1    | set 4 bytes per element
    btst.l    #23,%d0    | test if string array
    beq     lab1EDF    | branch if not string

    moveq    #6,%d1    | else 6 bytes per element
lab1EDF:
    move.l    %d1,%a3@(Asptl)    | set array data size (bytes per element)
    move.b    %a3@(Dimcnt),%d1    | get dimensions count
    addq.w    #4,%a0    | skip the array size now (do not know it yet!)
    move.w    %d1,%a0@+    | set dimension count of array

| now calculate the array data space size

lab1EC0:

| If you want arrays to dimension themselves by default then comment out the test
| above and uncomment the next three code lines and the label lab1ED0

|    move.w    #0x0A,%d1    | set default dimension value, allow 0 to 9
|    tst.b    %a3@(Defdim)    | test default DIM flag
|    bne.s    lab1ED0    | branch if b6 of Defdim is clear

    move.w    %sp@+,%d1    | get dimension size
|lab1ED0
    move.w    %d1,%a0@+    | save to array header
    bsr    lab1F7C    | do this dimension size+1 | array size
            | (d1+1)*(Asptl), result in d0
    move.l    %d0,%a3@(Asptl)    | save array data size
    subq.b    #1,%a3@(Dimcnt)    | decrement dimensions count
    bne.s    lab1EC0    | loop while not = 0

    adda.l    %a3@(Asptl),%a0    | add size to first element address
    bcs    labOMER    | if overflow go do "Out of memory" error

    cmpA.l    %a3@(Sstorl),%a0    | compare with bottom of string memory
    bcs.s    lab1ED6    | branch if less (is ok)

    bsr    labGARB    | do garbage collection routine
    cmpA.l    %a3@(Sstorl),%a0    | compare with bottom of string memory
    bcc    labOMER    | if Sstorl <= a0 do "Out of memory"
            | error then warm start

lab1ED6:    | ok exit, carry set
    move.l    %a0,%a3@(Earryl)    | save array mem end
    moveq    #0,%d0    | zero d0
    move.l    %a3@(Asptl),%d1    | get size in bytes
    lsr.l    #1,%d1    | /2 for word fill (may be odd # words)
    subq.w    #1,%d1    | adjust for dbf loop
lab1ED8:
    move.w    %d0,%a0@-    | decrement pointer and clear word
    dbf    %d1,lab1ED8    | decrement & loop until low word done

    swap    %d1    | swap words
    tst.w    %d1    | test high word
    beq     lab1F07    | exit if done

    subq.w    #1,%d1    | decrement low (high) word
    swap    %d1    | swap back
    bra      lab1ED8    | go do a whole block

| now we need to calculate the array size by doing Earryl - Astrtl

lab1F07:
    movea.l    %a3@(Astrtl),%a0    | get for calculation and as pointer
    move.l    %a3@(Earryl),%d0    | get array memory end
    sub.l    %a0,%d0    | calculate array size
    move.l    %d0,%a0@(4)    | save size to array
    tst.b    %a3@(Defdim)    | test default DIM flag
    bne.s    rts_011    | exit (RET) if this was a DIM command

            | else, find element
    addq.w    #8,%a0    | index to dimension count
    move.w    %a0@+,%a3@(Dimcnt)    | get dimension count of the array

| we have found, or built, the array. now we need to find the element

lab1F28:
    moveq    #0,%d0    | clear first result
    move.l    %d0,%a3@(Asptl)    | clear array data pointer

| compare nth dimension bound %a0@ with nth index %sp@+
| if greater do array bounds error

lab1F2C:
    move.w    %a0@+,%d1    | get nth dimension bound
    cmp.w    %sp@,%d1    | compare nth index with nth dimension bound
    bcs    labABER    | if d1 less or = do array bounds error

| now do pointer = pointer | nth dimension + nth index

    tst.l    %d0    | test pointer
    beq     lab1F5A    | skip multiply if last result = null

    bsr      lab1F7C    | do this dimension size+1 | array size
lab1F5A:
    moveq    #0,%d1    | clear longword
    move.w    %sp@+,%d1    | get nth dimension index
    add.l    %d1,%d0    | add index to size
    move.l    %d0,%a3@(Asptl)    | save array data pointer

    subq.b    #1,%a3@(Dimcnt)    | decrement dimensions count
    bne.s    lab1F2C    | loop if dimensions still to do

    move.b    #0,%a3@(Dtypef)    | set data type to float
    moveq    #3,%d1    | set for numeric array
    tst.b    %a3@(Varname+1)    | test if string array
    bpl.s    lab1F6A    | branch if not string

    moveq    #5,%d1    | else set for string array
    move.b    #0x80,%a3@(Dtypef)    | and set data type to string
    bra      lab1F6B    | skip integer test

lab1F6A:
    tst.b    %a3@(Varname+2)    | test if integer array
    bpl.s    lab1F6B    | branch if not integer

    move.b    #0x40,%a3@(Dtypef)    | else set data type to integer
lab1F6B:
    bsr      lab1F7C    | do element size (d1) | array size (Asptl)
    adda.l    %d0,%a0    | add array data start pointer
rts_011:
    rts


|************************************************************************************
|
| do this dimension size (d1) | array data size (Asptl)

| do a 16 x 32 bit multiply
| d1 holds the 16 bit multiplier
| Asptl holds the 32 bit multiplicand

| d0    bbbb    bbbb
| d1    0000    aaaa
|    ----------
| d0    rrrr    rrrr

lab1F7C:
    move.l    %a3@(Asptl),%d0    | get result
    move.l    %d0,%d2    | copy it
    swap    %d2    | shift high word to low word
    MULU.w    %d1,%d0    | d1 | low word = low result
    MULU.w    %d1,%d2    | d1 | high word = high result
    swap    %d2    | align words for test
    tst.w    %d2    | must be zero
    bne    labOMER    | if overflow go do "Out of memory" error

    add.l    %d2,%d0    | calculate result
    bcs    labOMER    | if overflow go do "Out of memory" error

    add.l    %a3@(Asptl),%d0    | add original
    bcs    labOMER    | if overflow go do "Out of memory" error

    rts


|************************************************************************************
|
| perform FRE()

labFRE:
    tst.b   %a3@(Dtypef)                | test data type, 0x80=string, 0x40=integer,
                                        | 0x00=float
    bpl.s   lab1FB4                     | branch if numeric

    bsr     lab22B6                     | pop string off descriptor stack, or from
                                        | top of string space, returns d0 = length,
                                        | a0 = pointer
    | FRE(n) was numeric so do this
lab1FB4:
    bsr     labGARB                     | go do garbage collection
    move.l  %a3@(Sstorl),%d0            | get bottom of string space
    sub.l   %a3@(Earryl),%d0            | subtract array mem end


|************************************************************************************
|
| convert d0 to signed longword in FAC1

labAYFC:
    move.b  #0x00,%a3@(Dtypef)          | clear data type, 0x80=string, 0x40=integer,
                                        | 0x00=float
    move.w  #0xA000,%a3@(FAC1_e)        | set FAC1 exponent and clear sign (b7)
    move.l  %d0,%a3@(FAC1_m)            | save FAC1 mantissa
    bpl     lab24D0                     | convert if +ve

    ori.b   #1,%ccr                     | else set carry
    bra     lab24D0                     | do +/- (carry is sign) & normalise FAC1


|************************************************************************************
|
| remember if the line length is zero (infinite line) then POS(n) will return
| position MOD tabsize

| perform POS()

labPOS:
    move.b    %a3@(TPos),%d0    | get terminal position

| convert d0 to unsigned byte in FAC1

lab1FD0:
    and.l    #0xFF,%d0    | clear high bits
    bra      labAYFC    | convert d0 to signed longword in FAC1 & RET

| check not direct (used by DEF and INPUT)

labCKRN:
    tst.b    %a3@(Clinel)    | test current line #
    bmi    labIDER    | if -ve go do illegal direct error then warm
            | start

    rts    | can continue so return


|************************************************************************************
|
| perform DEF

labDEF:
    move.L    #TK_FN-0x100,%d0    | get FN token
    bsr    labSCCA    | scan for CHR$(d0), else syntax error and
            | warm start
            | return character after d0
    move.b    #0x80,%a3@(Sufnxf)    | set FN flag bit
    bsr    lab1D12    | get FN name
    move.l    %a0,%a3@(func_l)    | save function pointer

    bsr      labCKRN    | check not direct (back here if ok)
    cmp.b    #0x28,%a5@+    | check next byte is "(" and increment
    bne    labSNER    | else do syntax error/warm start

    move.b    #0x7E,%a3@(Sufnxf)    | set FN variable flag bits
    bsr    labSVAR    | search for or create a variable
            | return the variable address in a0
    bsr    lab1BFB    | scan for ")", else do syntax error/warm start
    move.L    #TK_EQUAL-0x100,%d0    | = token
    bsr    labSCCA    | scan for CHR$(A), else syntax error/warm start
            | return character after d0
    move.l    %a3@(Varname),%sp@-    | push current variable name
    move.l    %a5,%sp@-    | push BASIC execute pointer
    bsr    labDATA    | go perform DATA, find end of DEF FN statement
    movea.l    %a3@(func_l),%a0    | get the function pointer
    move.l    %sp@+,%a0@    | save BASIC execute pointer to function
    move.l    %sp@+,%a0@(4)    | save current variable name to function
    rts


|************************************************************************************
|
| evaluate FNx

lab201E:
    move.b    #0x81,%a3@(Sufnxf)    | set FN flag (find not create)
    bsr    labIGBY    | increment & scan memory
    bsr    lab1D12    | get FN name
    move.b    %a3@(Dtypef),%sp@-    | push data type flag (function type)
    move.l    %a0,%sp@-    | push function pointer
    cmp.b    #0x28,%a5@    | check next byte is "(", no increment
    bne    labSNER    | else do syntax error/warm start

    bsr    lab1BF7    | evaluate expression within parentheses
    movea.l    %sp@+,%a0    | pop function pointer
    move.l    %a0,%a3@(func_l)    | set function pointer
    move.b    %a3@(Dtypef),%sp@-    | push data type flag (function expression type)

    move.l    %a0@(4),%d0    | get function variable name
    bsr    lab1D4A    | go find function variable (already created)

            | now check type match for variable
    move.b    %sp@+,%d0    | pop data type flag (function expression type)
    rol.b    #1,%d0    | set carry if type = string
    bsr    labCKTM    | type match check, set C for string

            | now stack the function variable value before
            | use
    beq     lab2043    | branch if not string

    lea    %a3@(des_sk_e),%a1    | get string stack pointer max+1
    cmpA.l    %a1,%a4    | compare string stack pointer with max+1
    beq    labSCER    | if no space on the stack go do string too
            | complex error

    move.w    %a0@(4),%a4@-    | string length on descriptor stack
    move.l    %a0@,%a4@-    | string address on stack
    bra      lab204S    | skip var push

lab2043:
    move.l    %a0@,%sp@-    | push variable
lab204S:
    move.l    %a0,%sp@-    | push variable address
    move.b    %a3@(Dtypef),%sp@-    | push variable data type

    bsr      lab2045    | pack function expression value into %a0@
            | (function variable)
    move.l    %a5,%sp@-    | push BASIC execute pointer
    movea.l    %a3@(func_l),%a0    | get function pointer
    movea.l    %a0@,%a5    | save function execute ptr as BASIC execute ptr
    bsr    labEVEX    | evaluate expression
    bsr    labGBYT    | scan memory
    bne    labSNER    | if not [EOL] or [EOS] do syntax error and
            | warm start

    move.l    %sp@+,%a5    | restore BASIC execute pointer

| restore variable from stack and test data type

    move.b    %sp@+,%d0    | pull variable data type
    movea.l    %sp@+,%a0    | pull variable address
    tst.b    %d0    | test variable data type
    bpl.s    lab204T    | branch if not string

    move.l    %a4@+,%a0@    | string address from descriptor stack
    move.w    %a4@+,%a0@(4)    | string length from descriptor stack
    bra      lab2044    | skip variable pull

lab204T:
    move.l    %sp@+,%a0@    | restore variable from stack
lab2044:
    move.b    %sp@+,%d0    | pop data type flag (function type)
    rol.b    #1,%d0    | set carry if type = string
    bsr    labCKTM    | type match check, set C for string
    rts

lab2045:
    tst.b    %a3@(Dtypef)    | test data type
    bpl    lab2778    | if numeric pack FAC1 into variable %a0@
            | and return

    movea.l    %a0,%a2    | copy variable pointer
    bra    lab17D6    | go do string LET & return



|************************************************************************************
|
| perform STR$()

labSTRS:
    bsr    lab2970    | convert FAC1 to string

| scan, set up string
| print double-quote-terminated string to FAC1 stack

lab20AE:
    moveq    #0x22,%d2    | set Srchc character (terminator 1)
    move.w    %d2,%d3    | set Asrch character (terminator 2)

| print d2/d3 terminated string to FAC1 stack
| d2 = Srchc, d3 = Asrch, a0 is source
| a6 is temp

lab20B4:
    moveq    #0,%d1    | clear longword
    subq.w    #1,%d1    | set length to -1
    movea.l    %a0,%a2    | copy start to calculate end
lab20BE:
    addq.w    #1,%d1    | increment length
    move.b    (%a0,%d1.w),%d0    | get byte from string
    beq     lab20D0    | exit loop if null byte [EOS]

    cmp.b    %d2,%d0    | compare with search character (terminator 1)
    beq     lab20CB    | branch if terminator

    cmp.b    %d3,%d0    | compare with terminator 2
    bne.s    lab20BE    | loop if not terminator 2 (or null string)

lab20CB:
    cmp.b    #0x22,%d0    | compare with double-quote
    bne.s    lab20D0    | branch if not double-quote

    addq.w    #1,%a2    | else increment string start (skip double-quote at end)
lab20D0:
    adda.l    %d1,%a2    | add longowrd length to make string end+1

    cmpA.l    %a3,%a0    | is string in ram
    bcs.s    labrtsT    | if not go push descriptor on stack & exit
            | (could be message string from ROM)

    cmpA.l    %a3@(Smeml),%a0    | is string in utility ram
    bcc      labrtsT    | if not go push descriptor on stack & exit
            | (is in string or program space)

            | (else) copy string to string memory
lab20C9:
    movea.l    %a0,%a1    | copy descriptor pointer
    move.l    %d1,%d0    | copy longword length
    bne.s    lab20D8    | branch if not null string

    movea.l    %d1,%a0    | make null pointer
    bra      labrtsT    | go push descriptor on stack & exit

lab20D8:
    bsr      lab2115    | make string space d1 bytes long
    adda.l    %d1,%a0    | new string end
    adda.l    %d1,%a1    | old string end
    subq.w    #1,%d0    | -1 for dbf loop
lab20E0:
    move.b    %a1@-,%a0@-    | copy byte (source can be odd aligned)
    dbf    %d0,lab20E0    | loop until done



|************************************************************************************
|
| check for space on descriptor stack then ...
| put string address and length on descriptor stack & update stack pointers
| start is in %a0, length is in d1

labrtsT:
    lea    %a3@(des_sk_e),%a1    | get string stack pointer max+1
    cmpA.l    %a1,%a4    | compare string stack pointer with max+1
    beq    labSCER    | if no space on string stack ..
            | .. go do 'string too complex' error

            | push string & update pointers
    move.w    %d1,%a4@-    | string length on descriptor stack
    move.l    %a0,%a4@-    | string address on stack
    move.l    %a4,%a3@(FAC1_m)    | string descriptor pointer in FAC1
    move.b    #0x80,%a3@(Dtypef)    | save data type flag, 0x80=string
    rts


|************************************************************************************
|
| build descriptor a0/d1
| make space in string memory for string d1.w long
| return pointer in a0/Sutill

lab2115:
    tst.w    %d1    | test length
    beq     lab2128    | branch if user wants null string

            | make space for string d1 long
    move.l    %d0,%sp@-    | save d0
    moveq    #0,%d0    | clear longword
    move.b    %d0,%a3@(Gclctd)    | clear garbage collected flag (b7)
    moveq    #1,%d0    | +1 to possibly round up
    and.w    %d1,%d0    | mask odd bit
    add.w    %d1,%d0    | ensure d0 is even length
    bcc      lab2117    | branch if no overflow

    moveq    #1,%d0    | set to allocate 65536 bytes
    swap    %d0    | makes 0x00010000
lab2117:
    movea.l    %a3@(Sstorl),%a0    | get bottom of string space
    suba.l    %d0,%a0    | subtract string length
    cmpA.l    %a3@(Earryl),%a0    | compare with top of array space
    bcs.s    lab2137    | if less do out of memory error

    move.l    %a0,%a3@(Sstorl)    | save bottom of string space
    move.l    %a0,%a3@(Sutill)    | save string utility pointer
    move.l    %sp@+,%d0    | restore d0
    tst.w    %d1    | set flags on length
    rts

lab2128:
    movea.w    %d1,%a0    | make null pointer
    rts

lab2137:
    tst.b    %a3@(Gclctd)    | get garbage collected flag
    bmi    labOMER    | do "Out of memory" error, then warm start

    move.l    %a1,%sp@-    | save a1
    bsr      labGARB    | else go do garbage collection
    movea.l    %sp@+,%a1    | restore a1
    move.b    #0x80,%a3@(Gclctd)    | set garbage collected flag
    bra      lab2117    | go try again


|************************************************************************************
|
| garbage collection routine

labGARB:
    movem.l    %d0-%d2/%a0-%a2,%sp@-    | save registers
    move.l    %a3@(Ememl),%a3@(Sstorl)    | start with no strings

            | re-run routine from last ending
lab214B:
    move.l    %a3@(Earryl),%d1    | set highest uncollected string so far
    moveq    #0,%d0    | clear longword
    movea.l    %d0,%a1    | clear string to move pointer
    movea.l    %a3@(Sstrl),%a0    | set pointer to start of strings
    lea    %a0@(4),%a0    | index to string pointer
    movea.l    %a3@(Sarryl),%a2    | set end pointer to start of arrays (end of
            | strings)
    bra      lab2176    | branch into loop at end loop test

lab2161:
    bsr    lab2206    | test and set if this is the highest string
    lea    %a0@(10),%a0    | increment to next string
lab2176:
    cmpA.l    %a2,%a0    | compare end of area with pointer
    bcs.s    lab2161    | go do next if not at end

| done strings, now do arrays.

    lea    %a0@(-4),%a0    | decrement pointer to start of arrays
    movea.l    %a3@(Earryl),%a2    | set end pointer to end of arrays
    bra      lab218F    | branch into loop at end loop test

lab217E:
    move.l    %a0@(4),%d2    | get array size
    add.l    %a0,%d2    | makes start of next array

    move.l    %a0@,%d0    | get array name
    btst    #23,%d0    | test string flag
    beq     lab218B    | branch if not string

    move.w    %a0@(8),%d0    | get # of dimensions
    add.w    %d0,%d0    | |2
    adda.w    %d0,%a0    | add to skip dimension size(s)
    lea    %a0@(10),%a0    | increment to first element
lab2183:
    bsr      lab2206    | test and set if this is the highest string
    addq.w    #6,%a0    | increment to next element
    cmpA.l    %d2,%a0    | compare with start of next array
    bne.s    lab2183    | go do next if not at end of array

lab218B:
    movea.l    %d2,%a0    | pointer to next array
lab218F:
    cmpA.l    %a0,%a2    | compare pointer with array end
    bne.s    lab217E    | go do next if not at end

| done arrays and variables, now just the descriptor stack to do

    movea.l    %a4,%a0    | get descriptor stack pointer
    lea    %a3@(des_sk),%a2    | set end pointer to end of stack
    bra      lab21C4    | branch into loop at end loop test

lab21C2:
    bsr      lab2206    | test and set if this is the highest string
    lea    %a0@(6),%a0    | increment to next string
lab21C4:
    cmpA.l    %a0,%a2    | compare pointer with stack end
    bne.s    lab21C2    | go do next if not at end

| descriptor search complete, now either exit or set-up and move string

    move.l    %a1,%d0    | set the flags (a1 is move string)
    beq     lab21D1    | go tidy up and exit if no move

    movea.l    %a1@,%a0    | a0 is now string start
    moveq    #0,%d1    | clear d1
    move.w    %a1@(4),%d1    | d1 is string length
    addq.l    #1,%d1    | +1
    and.b    #0xFE,%d1    | make even length
    adda.l    %d1,%a0    | pointer is now to string end+1
    movea.l    %a3@(Sstorl),%a2    | is destination end+1
    cmpA.l    %a2,%a0    | does the string need moving
    beq     lab2240    | branch if not

    lsr.l    #1,%d1    | word move so do /2
    subq.w    #1,%d1    | -1 for dbf loop
lab2216:
    move.w    %a0@-,%a2@-    | copy word
    dbf    %d1,lab2216    | loop until done

    move.l    %a2,%a1@    | save new string start
lab2240:
    move.l    %a1@,%a3@(Sstorl)    | string start is new string mem start
    bra    lab214B    | re-run routine from last ending
            | (but do not collect this string)

lab21D1:
    movem.l    %sp@+,%d0-%d2/%a0-%a2    | restore registers
    rts

| test and set if this is the highest string

lab2206:
    move.l    %a0@,%d0    | get this string pointer
    beq     rts_012    | exit if null string

    cmp.l    %d0,%d1    | compare with highest uncollected string so far
    bcc      rts_012    | exit if <= with highest so far

    cmp.l    %a3@(Sstorl),%d0    | compare with bottom of string space
    bcc      rts_012    | exit if >= bottom of string space

    moveq    #-1,%d0    | d0 = 0xFFFFFFFF
    move.w    %a0@(4),%d0    | d0 is string length
    neg.w    %d0    | make -ve
    and.b    #0xFE,%d0    | make -ve even length
    add.l    %a3@(Sstorl),%d0    | add string store to -ve length
    cmp.l    %a0@,%d0    | compare with string address
    beq     lab2212    | if = go move string store pointer down

    move.l    %a0@,%d1    | highest = current
    movea.l    %a0,%a1    | string to move = current
    rts

lab2212:
    move.l    %d0,%a3@(Sstorl)    | set new string store start
rts_012:
    rts


|************************************************************************************
|
| concatenate - add strings
| string descriptor 1 is in FAC1_m, string 2 is in line

lab224D:
    pea    %pc@(lab1ADB)    | continue evaluation after concatenate
    move.l    %a3@(FAC1_m),%sp@-    | stack descriptor pointer for string 1

    bsr    labGVAL    | get value from line
    tst.b    %a3@(Dtypef)    | test data type flag
    bpl    labTMER    | if type is not string do type mismatch error

    movea.l    %sp@+,%a0    | restore descriptor pointer for string 1

|************************************************************************************
|
| concatenate
| string descriptor 1 is in %a0, string descriptor 2 is in FAC1_m

lab224E:
    movea.l    %a3@(FAC1_m),%a1    | copy descriptor pointer 2
    move.w    %a0@(4),%d1    | get length 1
    add.w    %a1@(4),%d1    | add length 2
    bcs    labSLER    | if overflow go do 'string too long' error

    move.l    %a0,%sp@-    | save descriptor pointer 1
    bsr    lab2115    | make space d1 bytes long
    move.l    %a0,%a3@(FAC2_m)    | save new string start pointer
    movea.l    %sp@,%a0    | copy descriptor pointer 1 from stack
    move.w    %a0@(4),%d0    | get length
    movea.l    %a0@,%a0    | get string pointer
    bsr      lab229E    | copy string d0 bytes long from a0 to Sutill
            | return with a0 = pointer, d1 = length

    movea.l    %a3@(FAC1_m),%a0    | get descriptor pointer for string 2
    bsr      lab22BA    | pop %a0@ descriptor, returns with ..
            | a0 = pointer, d0 = length
    bsr      lab229E    | copy string d0 bytes long from a0 to Sutill
            | return with a0 = pointer, d1 = length

    movea.l    %sp@+,%a0    | get descriptor pointer for string 1
    bsr      lab22BA    | pop %a0@ descriptor, returns with ..
            | d0 = length, a0 = pointer

    movea.l    %a3@(FAC2_m),%a0    | retreive the result string pointer
    move.l    %a0,%d1    | copy the result string pointer
    beq    labrtsT    | if it is a null string just return it
            | a0 = pointer, d1 = length

    neg.l    %d1    | else make the start pointer negative
    add.l    %a3@(Sutill),%d1    | add the end pointert to give the length
    bra    labrtsT    | push string on descriptor stack
            | a0 = pointer, d1 = length


|************************************************************************************
|
| copy string d0 bytes long from a0 to Sutill
| return with a0 = pointer, d1 = length

lab229E:
    move.w    %d0,%d1    | copy and check length
    beq     rts_013    | skip copy if null

    movea.l    %a3@(Sutill),%a1    | get destination pointer
    move.l    %a1,%sp@-    | save destination string pointer
    subq.w    #1,%d0    | subtract for dbf loop
lab22A0:
    move.b    %a0@+,%a1@+    | copy byte
    dbf    %d0,lab22A0    | loop if not done

    move.l    %a1,%a3@(Sutill)    | update Sutill to end of copied string
    movea.l    %sp@+,%a0    | restore destination string pointer
rts_013:
    rts


|************************************************************************************
|
| pop string off descriptor stack, or from top of string space
| returns with d0.l = length, a0 = pointer

lab22B6:
    movea.l    %a3@(FAC1_m),%a0    | get descriptor pointer


|************************************************************************************
|
| pop %a0@ descriptor off stack or from string space
| returns with d0.l = length, a0 = pointer

lab22BA:
    movem.l    %a1/%d1,%sp@-    | save other regs
    cmpA.l    %a0,%a4    | is string on the descriptor stack
    bne.s    lab22BD    | skip pop if not

    addq.w    #0x06,%a4    | else update stack pointer
lab22BD:
    moveq    #0,%d0    | clear string length longword
    movea.l    %a0@+,%a1    | get string address
    move.w    %a0@+,%d0    | get string length

    cmpA.l    %a0,%a4    | was it on the descriptor stack
    bne.s    lab22E6    | branch if it was not

    cmpA.l    %a3@(Sstorl),%a1    | compare string address with bottom of string
            | space
    bne.s    lab22E6    | branch if <>

    moveq    #1,%d1    | mask for odd bit
    and.w    %d0,%d1    | and length
    add.l    %d0,%d1    | make it fit word aligned length

    add.l    %d1,%a3@(Sstorl)    | add to bottom of string space
lab22E6:
    movea.l    %a1,%a0    | copy to a0
    movem.l    %sp@+,%a1/%d1    | restore other regs
    tst.l    %d0    | set flags on length
    rts


|************************************************************************************
|
| perform CHR$()

labCHRS:
    bsr    labEVBY    | evaluate byte expression, result in d0 and
            | Itemp
labMKCHR:
    moveq    #1,%d1    | string is single byte
    bsr    lab2115    | make string space d1 bytes long
            | return a0/Sutill = pointer, others unchanged
    move.b    %d0,%a0@    | save byte in string (byte IS string!)
    bra    labrtsT    | push string on descriptor stack
            | a0 = pointer, d1 = length


|************************************************************************************
|
| perform LEFT$()

| enter with a0 is descriptor, d0 & Itemp is word 1

labLEFT:
    EXG    %d0,%d1    | word in d1
    bsr    lab1BFB    | scan for ")", else do syntax error/warm start

    tst.l    %d1    | test returned length
    beq     lab231C    | branch if null return

    moveq    #0,%d0    | clear start offset
    cmp.w    %a0@(4),%d1    | compare word parameter with string length
    bcs.s    lab231C    | branch if string length > word parameter

    bra      lab2317    | go copy whole string


|************************************************************************************
|
| perform RIGHT$()

| enter with a0 is descriptor, d0 & Itemp is word 1

labRIGHT:
    EXG    %d0,%d1    | word in d1
    bsr    lab1BFB    | scan for ")", else do syntax error/warm start

    tst.l    %d1    | test returned length
    beq     lab231C    | branch if null return

    move.w    %a0@(4),%d0    | get string length
    sub.l    %d1,%d0    | subtract word
    bcc      lab231C    | branch if string length > word parameter

            | else copy whole string
lab2316:
    moveq    #0,%d0    | clear start offset
lab2317:
    move.w    %a0@(4),%d1    | else make parameter = length

| get here with ...
|    a0 - points to descriptor
|    d0 - is offset from string start
|    d1 - is required string length

lab231C:
    movea.l    %a0,%a1    | save string descriptor pointer
    bsr    lab2115    | make string space d1 bytes long
            | return a0/Sutill = pointer, others unchanged
    movea.l    %a1,%a0    | restore string descriptor pointer
    move.l    %d0,%sp@-    | save start offset (longword)
    bsr      lab22BA    | pop %a0@ descriptor, returns with ..
            | d0 = length, a0 = pointer
    adda.l    %sp@+,%a0    | adjust pointer to start of wanted string
    move.w    %d1,%d0    | length to d0
    bsr    lab229E    | store string d0 bytes long from %a0@ to
            | (Sutill) return with a0 = pointer,
            | d1 = length
    bra    labrtsT    | push string on descriptor stack
            | a0 = pointer, d1 = length


|************************************************************************************
|
| perform MID$()

| enter with a0 is descriptor, d0 & Itemp is word 1

labMIDS:
    moveq    #0,%d7    | clear longword
    subq.w    #1,%d7    | set default length = 65535
    move.l    %d0,%sp@-    | save word 1
    bsr    labGBYT    | scan memory
    cmp.b    #',',%d0    | was it ","
    bne.s    lab2358    | branch if not "," (skip second byte get)

    move.b    %a5@+,%d0    | increment pointer past ","
    move.l    %a0,%sp@-    | save descriptor pointer
    bsr    labGTWO    | get word parameter, result in d0 and Itemp
    movea.l    %sp@+,%a0    | restore descriptor pointer
    move.l    %d0,%d7    | copy length
lab2358:
    bsr    lab1BFB    | scan for ")", else do syntax error then warm
            | start
    move.l    %sp@+,%d0    | restore word 1
    moveq    #0,%d1    | null length
    subq.l    #1,%d0    | decrement start index (word 1)
    bmi    labFCER    | if was null do function call error then warm
            | start

    cmp.w    %a0@(4),%d0    | compare string length with start index
    bcc      lab231C    | if start not in string do null string (d1=0)

    move.l    %d7,%d1    | get length back
    add.w    %d0,%d7    | d7 now = MID$() end
    bcs.s    lab2368    | already too long so do RIGHT$ equivalent

    cmp.w    %a0@(4),%d7    | compare string length with start index+length
    bcs.s    lab231C    | if end in string go do string

lab2368:
    move.w    %a0@(4),%d1    | get string length
    sub.w    %d0,%d1    | subtract start offset
    bra      lab231C    | go do string (effectively RIGHT$)


|************************************************************************************
|
| perform LCASE$()

labLCASE:
    bsr    lab22B6    | pop string off descriptor stack or from memory
            | returns with d0 = length, a0 = pointer
    move.l    %d0,%d1    | copy the string length
    beq     NoString    | if null go return a null string

| else copy and change the string

    movea.l    %a0,%a1    | copy the string address
    bsr    lab2115    | make a string space d1 bytes long
    adda.l    %d1,%a0    | new string end
    adda.l    %d1,%a1    | old string end
    move.w    %d1,%d2    | copy length for loop
    subq.w    #1,%d2    | -1 for dbf loop
LC_loop:
    move.b    %a1@-,%d0    | get byte from string

    cmp.b    #0x5B,%d0    | compare with "Z"+1
    bcc      NoUcase    | if > "Z" skip change

    cmp.b    #0x41,%d0    | compare with "A"
    bcs.s    NoUcase    | if < "A" skip change

    ori.b    #0x20,%d0    | convert upper case to lower case
NoUcase:
    move.b    %d0,%a0@-    | copy upper case byte back to string
    dbf    %d2,LC_loop    | decrement and loop if not all done

    bra      NoString    | tidy up & exit (branch always)


|************************************************************************************
|
| perform UCASE$()

labUCASE:
    bsr    lab22B6    | pop string off descriptor stack or from memory
            | returns with d0 = length, a0 = pointer
    move.l    %d0,%d1    | copy the string length
    beq     NoString    | if null go return a null string

| else copy and change the string

    movea.l    %a0,%a1    | copy the string address
    bsr    lab2115    | make a string space d1 bytes long
    adda.l    %d1,%a0    | new string end
    adda.l    %d1,%a1    | old string end
    move.w    %d1,%d2    | copy length for loop
    subq.w    #1,%d2    | -1 for dbf loop
UC_loop:
    move.b    %a1@-,%d0    | get a byte from the string

    cmp.b    #0x61,%d0    | compare with "a"
    bcs.s    NoLcase    | if < "a" skip change

    cmp.b    #0x7B,%d0    | compare with "z"+1
    bcc      NoLcase    | if > "z" skip change

    andi.b    #0xDF,%d0    | convert lower case to upper case
NoLcase:
    move.b    %d0,%a0@-    | copy upper case byte back to string
    dbf    %d2,UC_loop    | decrement and loop if not all done

NoString:
    bra    labrtsT    | push string on descriptor stack
            | a0 = pointer, d1 = length


|************************************************************************************
|
| perform SADD()

labSADD:
    move.b    %a5@+,%d0    | increment pointer
    bsr    labGVAR    | get variable address in a0
    bsr    lab1BFB    | scan for ")", else do syntax error/warm start
    tst.b    %a3@(Dtypef)    | test data type flag
    bpl    labTMER    | if numeric do Type missmatch Error

| if you want a non existant variable to return a null value then set the novar
| value at the top of this file to some non zero value

    .ifndef    novar

    move.l    %a0,%d0    | test the variable found flag
    beq    labAYFC    | if not found go return null

    .endif

    move.l    %a0@,%d0    | get string address
    bra    labAYFC    | convert d0 to signed longword in FAC1 & return


|************************************************************************************
|
| perform LEN()

labLENS:
    pea    %pc@(labAYFC)    | set return address to convert d0 to signed
            | longword in FAC1
    bra    lab22B6    | pop string off descriptor stack or from memory
            | returns with d0 = length, a0 = pointer


|************************************************************************************
|
| perform ASC()

labASC:
    bsr    lab22B6    | pop string off descriptor stack or from memory
            | returns with d0 = length, a0 = pointer
    tst.w    %d0    | test length
    beq    labFCER    | if null do function call error then warm start

    move.b    %a0@,%d0    | get first character byte
    bra    lab1FD0    | convert d0 to unsigned byte in FAC1 & return


|************************************************************************************
|
| increment and get byte, result in d0 and Itemp

labSGBY:
    bsr    labIGBY    | increment & scan memory


|************************************************************************************
|
| get byte parameter, result in d0 and Itemp

labGTBY:
    bsr    labEVNM    | evaluate expression & check is numeric,
            | else do type mismatch


|************************************************************************************
|
| evaluate byte expression, result in d0 and Itemp

labEVBY:
    bsr    labEVPI    | evaluate positive integer expression
            | result in d0 and Itemp
    move.l    #0x80,%d1    | set mask/2
    add.l    %d1,%d1    | =0xFFFFFF00
    and.l    %d0,%d1    | check top 24 bits
    bne    labFCER    | if <> 0 do function call error/warm start

    rts


|************************************************************************************
|
| get word parameter, result in d0 and Itemp

labGTWO:
    bsr    labEVNM    | evaluate expression & check is numeric,
            | else do type mismatch
    bsr    labEVPI    | evaluate positive integer expression
            | result in d0 and Itemp
    swap    %d0    | copy high word to low word
    tst.w    %d0    | set flags
    bne    labFCER    | if <> 0 do function call error/warm start

    swap    %d0    | copy high word to low word
    rts


|************************************************************************************
|
| perform VAL()

labVAL:
    bsr    lab22B6    | pop string off descriptor stack or from memory
            | returns with d0 = length, a0 = pointer
    beq     labVALZ    | string was null so set result = 0x00
            | clear FAC1 exponent & sign & return

    movea.l    %a5,%a6    | save BASIC execute pointer
    movea.l    %a0,%a5    | copy string pointer to execute pointer
    adda.l    %d0,%a0    | string end+1
    move.b    %a0@,%d0    | get byte from string+1
    move.w    %d0,%sp@-    | save it
    move.l    %a0,%sp@-    | save address
    move.b    #0,%a0@    | null terminate string
    bsr    labGBYT    | scan memory
    bsr    lab2887    | get FAC1 from string
    movea.l    %sp@+,%a0    | restore pointer
    move.w    %sp@+,%d0    | pop byte
    move.b    %d0,%a0@    | restore to memory
    movea.l    %a6,%a5    | restore BASIC execute pointer
    rts

labVALZ:
    move.w    %d0,%a3@(FAC1_e)    | clear FAC1 exponent & sign
    rts


|************************************************************************************
|
| get two parameters for POKE or WAIT, first parameter in %a0, second in d0

labGADB:
    bsr    labEVNM    | evaluate expression & check is numeric,
            | else do type mismatch
    bsr    labEVIR    | evaluate integer expression
            | (does FC error not OF error if out of range)
    move.l    %d0,%sp@-    | copy to stack
    bsr    lab1C01    | scan for ",", else do syntax error/warm start
    bsr      labGTBY    | get byte parameter, result in d0 and Itemp
    movea.l    %sp@+,%a0    | pull address
    rts


|************************************************************************************
|
| get two parameters for DOKE or WAITW, first parameter in %a0, second in d0

labGADW:
    bsr      labGEAD    | get even address for word/long memory actions
            | address returned in d0 and on the stack
    bsr    lab1C01    | scan for ",", else do syntax error/warm start
    bsr    labEVNM    | evaluate expression & check is numeric,
            | else do type mismatch
    bsr    labEVIR    | evaluate integer expression
            | result in d0 and Itemp
    swap    %d0    | swap words
    tst.w    %d0    | test high word
    beq     labXGADW    | exit if null

    addq.w    #1,%d0    | increment word
    bne    labFCER    | if <> 0 do function call error/warm start

labXGADW:
    swap    %d0    | swap words back
    movea.l    %sp@+,%a0    | pull address
    rts


|************************************************************************************
|
| get even address (for word or longword memory actions)
| address returned in d0 and on the stack
| does address error if the address is odd

labGEAD:
    bsr    labEVNM    | evaluate expression & check is numeric,
            | else do type mismatch
    bsr    labEVIR    | evaluate integer expression
            | (does FC error not OF error if out of range)
    btst    #0,%d0    | test low bit of longword
    bne    labADER    | if address is odd do address error/warm start

    movea.l    %sp@,%a0    | copy return address
    move.l    %d0,%sp@    | even address on stack
    jmp    %a0@    | effectively rts


|************************************************************************************
|
| perform PEEK()

labPEEK:
    bsr    labEVIR    | evaluate integer expression
            | (does FC error not OF error if out of range)
    movea.l    %d0,%a0    | copy to address register
    move.b    %a0@,%d0    | get byte
    bra    lab1FD0    | convert d0 to unsigned byte in FAC1 & return


|************************************************************************************
|
| perform POKE

labPOKE:
    bsr      labGADB    | get two parameters for POKE or WAIT
            | first parameter in %a0, second in d0
    move.b    %d0,%a0@    | put byte in memory
    rts


|************************************************************************************
|
| perform DEEK()

labDEEK:
    bsr    labEVIR    | evaluate integer expression
            | (does FC error not OF error if out of range)
    lsr.b    #1,%d0    | shift bit 0 to carry
    bcs    labADER    | if address is odd do address error/warm start

    add.b    %d0,%d0    | shift byte back
    EXG    %d0,%a0    | copy to address register
    moveq    #0,%d0    | clear top bits
    move.w    %a0@,%d0    | get word
    bra    labAYFC    | convert d0 to signed longword in FAC1 & return


|************************************************************************************
|
| perform LEEK()

labLEEK:
    bsr    labEVIR    | evaluate integer expression
            | (does FC error not OF error if out of range)
    lsr.b    #1,%d0    | shift bit 0 to carry
    bcs    labADER    | if address is odd do address error/warm start

    add.b    %d0,%d0    | shift byte back
    EXG    %d0,%a0    | copy to address register
    move.l    %a0@,%d0    | get longword
    bra    labAYFC    | convert d0 to signed longword in FAC1 & return


|************************************************************************************
|
| perform DOKE

labDOKE:
    bsr      labGADW    | get two parameters for DOKE or WAIT
            | first parameter in %a0, second in d0
    move.w    %d0,%a0@    | put word in memory
    rts


|************************************************************************************
|
| perform LOKE

labLOKE:
    bsr      labGEAD    | get even address for word/long memory actions
            | address returned in d0 and on the stack
    bsr    lab1C01    | scan for ",", else do syntax error/warm start
    bsr    labEVNM    | evaluate expression & check is numeric,
            | else do type mismatch
    bsr    labEVIR    | evaluate integer value (no sign check)
    movea.l    %sp@+,%a0    | pull address
    move.l    %d0,%a0@    | put longword in memory
rts_015:
    rts


|************************************************************************************
|
| perform swap

labswap:
    bsr    labGVAR    | get variable 1 address in a0
    move.l    %a0,%sp@-    | save variable 1 address
    move.b    %a3@(Dtypef),%d4    | copy variable 1 data type, 0x80=string,
            | 0x40=inetger, 0x00=float

    bsr    lab1C01    | scan for ",", else do syntax error/warm start
    bsr    labGVAR    | get variable 2 address in a0
    movea.l    %sp@+,%a2    | restore variable 1 address
    cmp.b    %a3@(Dtypef),%d4    | compare variable 1 data type with variable 2
            | data type
    bne    labTMER    | if not both the same type do "Type mismatch"
            | error then warm start

| if you do want a non existant variable to return an error then leave the novar
| value at the top of this file set to zero

    .ifdef    novar

    move.l    %a0@,%d0    | get variable 2
    move.l    %a2@,%a0@+    | copy variable 1 to variable 2
    move.l    %d0,%a2@+    | save variable 2 to variable 1

    tst.b    %d4    | check data type
    bpl.s    rts_015    | exit if not string

    move.w    %a0@,%d0    | get string 2 length
    move.w    %a2@,%a0@    | copy string 1 length to string 2 length
    move.w    %d0,%a2@    | save string 2 length to string 1 length

    .endif


| if you want a non existant variable to return a null value then set the novar
| value at the top of this file to some non zero value

    .ifndef    novar

    move.l    %a2,%d2    | copy the variable 1 pointer
    move.l    %d2,%d3    | and again for any length
    beq     no_variable1    | if variable 1 does not exist skip the
            | value get

    move.l    %a2@,%d2    | get variable 1 value
    tst.b    %d4    | check the data type
    bpl.s    no_variable1    | if not string skip the length get

    move.w    %a2@(4),%d3    | else get variable 1 string length
no_variable1
    move.l    %a0,%d0    | copy the variable 2 pointer
    move.l    %d0,%d1    | and again for any length
    beq     no_variable2    | if variable 2 does not exist skip the
            | value get and the new value save

    move.l    %a0@,%d0    | get variable 2 value
    move.l    %d2,%a0@+    | save variable 2 new value
    tst.b    %d4    | check the data type
    bpl.s    no_variable2    | if not string skip the length get and
            | new length save

    move.w    %a0@,%d1    | else get variable 2 string length
    move.w    %d3,%a0@    | save variable 2 new string length
no_variable2
    tst.l    %d2    | test if variable 1 exists
    beq     EXIT_swap    | if variable 1 does not exist skip the
            | new value save

    move.l    %d0,%a2@+    | save variable 1 new value
    tst.b    %d4    | check the data type
    bpl.s    EXIT_swap    | if not string skip the new length save

    move.w    %d1,%a2@    | save variable 1 new string length
EXIT_swap:

    .endif

    rts


|************************************************************************************
|
| perform USR

labUSR:
    jsr    %a3@(Usrjmp)    | do user vector
    bra    lab1BFB    | scan for ")", else do syntax error/warm start


|************************************************************************************
|
| perform LOAD

labLOAD:
    jmp    %a3@(V_LOAD)    | do load vector


|************************************************************************************
|
| perform SAVE

labSAVE:
    jmp    %a3@(V_SAVE)    | do save vector


|************************************************************************************
|
| perform CALL

labCALL:
    pea    %pc@(labGBYT)    | put return address on stack
    bsr    labGEAD    | get even address for word/long memory actions
            | address returned in d0 and on the stack
    rts    | effectively calls the routine

| if the called routine exits correctly then it will return via the get byte routine.
| this will then get the next byte for the interpreter and return


|************************************************************************************
|
| perform WAIT

labWAIT:
    bsr    labGADB    | get two parameters for POKE or WAIT
            | first parameter in %a0, second in d0
    move.l    %a0,%sp@-    | save address
    move.w    %d0,%sp@-    | save byte
    moveq    #0,%d2    | clear mask
    bsr    labGBYT    | scan memory
    beq     lab2441    | skip if no third argument

    bsr    labSCGB    | scan for "," & get byte,
            | else do syntax error/warm start
    move.l    %d0,%d2    | copy mask
lab2441:
    move.w    %sp@+,%d1    | get byte
    movea.l    %sp@+,%a0    | get address
lab2445:
    move.b    %a0@,%d0    | read memory byte
    eor.b    %d2,%d0    | eor with second argument (mask)
    and.b    %d1,%d0    | and with first argument (byte)
    beq     lab2445    | loop if result is zero

    rts


|************************************************************************************
|
| perform subtraction, FAC1 from FAC2

|labSUBTRACT:
|    FPUTEST                             | check for FPU
|    beq     labSUBnoFPU                 | if no FPU then emulate
|    FAC2toD0                            | get FAC2
|    fmove.s %d0,%fp0                    | and copy to %fp0
|    FAC1toD0                            | get FAC1
|    fsub.s  %d0,%fp0                    | subtract FAC2 from FAC2
|    fmove.s %fp0,%d0                    | copy result to D0
|    D0toFAC1                            | and save result in FAC1
|    rts

labSUBTRACT:
    FPUTEST                             | check for FPU presence
    beq     labSUBnoFPU                 | if no FPU then emulate
    cmp.w   #0xA000,%a3@(FAC2_e)        | check if FAC2 is integer
    beq     labSUBF2Int                 | FAC2 is integer
    FAC2toD0                            | fetch FAC2 as sfloat
    fmove.s %d0,%fp0                    | send FAC2 to FPU as sfloat
    bra.s   labSUBF1                    | jump ahead to loading FAC1
labSUBF2Int:
    fmove.l  %a3@(FAC2_m),%fp0          | send FAC2 to FPU as integer
labSUBF1:
    cmp.w   #0xA000,%a3@(FAC1_e)        | check if FAC1 is integer
    beq     labSUBF1Int                 | FAC1 is integer
    FAC1toD0                            | fetch FAC1 as sfloat
    fsub.s  %d0,%fp0                    | subtract FAC2 from FAC1 as sfloat
labSUBend:
    fmove.s %fp0,%d0                    | get result from FPU
    D0toFAC1                            | save result in FAC1
    rts
labSUBF1Int:
    fsub.l  %a3@(FAC1_m),%fp0           | subtract FAC2 from FAC1 as integer
    bra     labSUBend


labSUBnoFPU:
    eori.b    #0x80,%a3@(FAC1_s)    | complement FAC1 sign
    move.b    %a3@(FAC2_s),%a3@(FAC_sc)    | copy FAC2 sign byte

    move.b    %a3@(FAC1_s),%d0    | get FAC1 sign byte
    eor.b    %d0,%a3@(FAC_sc)    | eor with FAC2 sign
    bra      labADDnoFPU    | fall through to no-FPU addition


|************************************************************************************
|
| add FAC2 to FAC1

|labADD:
|    FPUTEST                             | check for FPU
|    beq.s   labADDnoFPU                | if no FPU then emulate
|    FAC2toD0                            | get FAC2
|    fmove.s %d0,%fp0                    | and copy to %fp0
|    FAC1toD0                            | get FAC1
|    fadd.s  %d0,%fp0                    | add FAC1 to FAC2
|    fmove.s %fp0,%d0                    | copy result to D0
|    D0toFAC1                            | and save result in FAC1
|    rts

labADD:
    FPUTEST                             | check for FPU
    beq     labADDnoFPU                 | if no FPU then emulate
    cmp.w   #0xA000,%a3@(FAC2_e)        | check if FAC2 is integer
    beq     labADDF2Int                 | FAC2 is integer
    FAC2toD0                            | fetch FAC2 as sfloat
    fmove.s %d0,%fp0                    | send FAC2 to FPU as sfloat
    bra.s   labADDF1                    | jump ahead to loading FAC1
labADDF2Int:
    fmove.l  %a3@(FAC2_m),%fp0          | send FAC2 to FPU as integer
labADDF1:
    cmp.w   #0xA000,%a3@(FAC1_e)        | check if FAC1 is integer
    beq     labADDF1Int                 | FAC1 is integer
    FAC1toD0                            | fetch FAC1 as sfloat
    fadd.s  %d0,%fp0                    | add FAC2 to FAC1 as sfloat
labADDend:
    fmove.s %fp0,%d0                    | get result from FPU
    D0toFAC1                            | save result in FAC1
    rts
labADDF1Int:
    fsub.l  %a3@(FAC1_m),%fp0           | add FAC2 to FAC1 as integer
    bra     labADDend


labADDnoFPU:
    move.b  %a3@(FAC1_e),%d0            | get exponent
    beq     lab279B                     | FAC1 was zero so copy FAC2 to FAC1 & return

    | FAC1 is non zero
    lea     %a3@(FAC2_m),%a0            | set pointer1 to FAC2 mantissa
    move.b  %a3@(FAC2_e),%d0            | get FAC2 exponent
    beq     rts_016                     | exit if zero

    sub.b   %a3@(FAC1_e),%d0            | subtract FAC1 exponent
    beq     lab24A8                     | branch if = (go add mantissa)

    bcs.s   lab249C                     | branch if FAC2 < FAC1

    | FAC2 > FAC1
    move.w  %a3@(FAC2_e),%a3@(FAC1_e)   | copy sign and exponent of FAC2
    neg.b   %d0                         | negate exponent difference (make diff -ve)
    subq.w  #8,%a0                      | pointer1 to FAC1

lab249C:
    neg.b   %d0                         | negate exponent difference (make diff +ve)
    move.l  %d1,%sp@-                   | save d1
    cmp.b   #32,%d0                     | compare exponent diff with 32
    blt.s   lab2467                     | branch if range >= 32

    moveq   #0,%d1                      | clear d1
    bra     lab2468                     | go clear smaller mantissa

lab2467:
    move.l  %a0@,%d1                    | get FACx mantissa
    lsr.l   %d0,%d1                     | shift d0 times right
lab2468:
    move.l  %d1,%a0@                    | save it back
    move.l  %sp@+,%d1                   | restore d1

    | exponents are equal now do mantissa add or subtract
lab24A8:
    tst.b   %a3@(FAC_sc)                | test sign compare (FAC1 eor FAC2)
    bmi     lab24F8                     | if <> go do subtract

    move.l  %a3@(FAC2_m),%d0            | get FAC2 mantissa
    add.l   %a3@(FAC1_m),%d0            | add FAC1 mantissa
    bcc     lab24F7                     | save and exit if no carry (FAC1 is normal)

    roxr.l  #1,%d0                      | else shift carry back into mantissa
    addq.b  #1,%a3@(FAC1_e)             | increment FAC1 exponent
    bcs     labOFER                     | if carry do overflow error & warm start

lab24F7:
    move.l  %d0,%a3@(FAC1_m)            | save mantissa
rts_016:
    rts

    | signs are different
lab24F8:
    lea     %a3@(FAC1_m),%a1            | pointer 2 to FAC1
    cmpA.l  %a0,%a1                     | compare pointers
    bne.s   lab24B4                     | branch if <>

    addq.w  #8,%a1                      | else pointer2 to FAC2

    | take smaller from bigger (take sign of bigger)
lab24B4:
    move.l  %a1@,%d0                    | get larger mantissa
    move.l  %a0@,%d1                    | get smaller mantissa
    move.l  %d0,%a3@(FAC1_m)            | save larger mantissa
    sub.l   %d1,%a3@(FAC1_m)            | subtract smaller


|************************************************************************************
|
| do +/- (carry is sign) & normalise FAC1

lab24D0:
    bcc     lab24D5                     | branch if result is +ve

    | erk! subtract is the wrong way round so
    | negate everything
    eori.b  #0xFF,%a3@(FAC1_s)          | complement FAC1 sign
    neg.l   %a3@(FAC1_m)                | negate FAC1 mantissa


|************************************************************************************
|
| normalise FAC1

lab24D5:
    move.l  %a3@(FAC1_m),%d0            | get mantissa
    bmi     lab24DA                     | mantissa is normal so just exit

    bne.s   lab24D9                     | mantissa is not zero so go normalise FAC1

    move.w  %d0,%a3@(FAC1_e)            | else make FAC1 = +zero
    rts

lab24D9:
    move.l  %d1,%sp@-                   | save d1
    move.l  %d0,%d1                     | mantissa to d1
    moveq   #0,%d0                      | clear d0
    move.b  %a3@(FAC1_e),%d0            | get exponent byte
    beq     lab24D8                     | if exponent is zero then clean up and exit
lab24D6:
    add.l   %d1,%d1                     | shift mantissa, add is quicker for a single
                                        | shift
    dbmi    %d0,lab24D6                 | decrement exponent and loop if mantissa and
                                        | exponent +ve

    tst.w   %d0                         | test exponent
    beq     lab24D8                     | if exponent is zero make FAC1 zero

    bpl.s   lab24D7                     | if exponent is >zero go save FAC1

    moveq   #1,%d0                      | else set for zero after correction
lab24D7:
    subq.b  #1,%d0                      | adjust exponent for loop
    move.l  %d1,%a3@(FAC1_m)            | save normalised mantissa
lab24D8:
    move.l  %sp@+,%d1                   | restore d1
    move.b  %d0,%a3@(FAC1_e)            | save corrected exponent
lab24DA:
    rts


|************************************************************************************
|
| perform LOG()

|labLOG:
|    FPUTEST
|    beq     .labLOG_NOFPU        | jump to no FPU
|    FAC1toD0                    | fetch FAC1 to D0
|    FLOG10.s    %d0,%fp0            | Log base 10 of D0
|    fmove.s    %fp0,%d0                | fetch result
|    D0toFAC1                    | store result in FAC1
|    rts

labLOG:
    FPUTEST                             | check for FPU
    beq     .labLOG_NOFPU               | if no FPU then emulate
    cmp.w   #0xA000,%a3@(FAC1_e)        | check if FAC1 is integer
    beq     labLOGF1Int                 | FAC1 is integer
    FAC1toD0                            | fetch FAC1 as sfloat
    flog10.s %d0,%fp0                   | Log base 10 of D0 as sfloat
labLOGend:
    fmove.s %fp0,%d0                    | fetch result
    D0toFAC1                            | store result in FAC1
    rts
labLOGF1Int:
    flog10.l %a3@(FAC1_m),%fp0          | Log base 10 of FAC1 as integer
    bra     labLOGend


.labLOG_NOFPU:
    tst.b    %a3@(FAC1_s)    | test sign
    bmi    labFCER    | if -ve do function call error/warm start

    moveq    #0,%d7    | clear d7
    move.b    %d7,%a3@(FAC_sc)    | clear sign compare
    move.b    %a3@(FAC1_e),%d7    | get exponent
    beq    labFCER    | if 0 do function call error/warm start

    sub.l    #0x81,%d7    | normalise exponent
    move.b    #0x81,%a3@(FAC1_e)    | force a value between 1 and 2
    move.l    %a3@(FAC1_m),%d6    | copy mantissa

    move.l    #0x80000000,%a3@(FAC2_m)    | set mantissa for 1
    move.w    #0x8100,%a3@(FAC2_e)    | set exponent for 1
    bsr    labADD    | find arg+1
    moveq    #0,%d0    | setup for calc skip
    move.w    %d0,%a3@(FAC2_e)    | set FAC1 for zero result
    add.l    %d6,%d6    | shift 1 bit out
    move.l    %d6,%a3@(FAC2_m)    | put back FAC2
    beq     labLONN    | if 0 skip calculation

    move.w    #0x8000,%a3@(FAC2_e)    | set exponent for .5
    bsr    labDIVIDE    | do (arg-1)/(arg+1)
    tst.b    %a3@(FAC1_e)    | test exponent
    beq     labLONN    | if 0 skip calculation

    move.b    %a3@(FAC1_e),%d1    | get exponent
    sub.b    #0x82,%d1    | normalise and two integer bits
    neg.b    %d1    | negate for shift
|*    cmp.b    #0x1F,%d1    | will mantissa vanish?
|*    bgt.s    labdunno    | if so do ???

    move.l    %a3@(FAC1_m),%d0    | get mantissa
    lsr.l    %d1,%d0    | shift in two integer bits

| d0 = arg
| d0 = x, d1 = y
| d2 = x1, d3 = y1
| d4 = shift count
| d5 = loop count
| d6 = z
| a0 = table pointer

    moveq    #0,%d6    | z = 0
    move.l    #1<<30,%d1    | y = 1
    lea    %pc@(TAB_HTHET),%a0    | get pointer to hyperbolic tangent table
    moveq    #30,%d5    | loop 31 times
    moveq    #1,%d4    | set shift count
    bra      labLOCC    | entry point for loop

labLAAD:
    ASR.l    %d4,%d2    | x1 >> i
    sub.l    %d2,%d1    | y = y - x1
    add.l    %a0@,%d6    | z = z + tanh(i)
labLOCC:
    move.l    %d0,%d2    | x1 = x
    move.l    %d1,%d3    | y1 = Y
    ASR.l    %d4,%d3    | y1 >> i
    bcc      labLOLP

    addq.l    #1,%d3
labLOLP:
    sub.l    %d3,%d0    | x = x - y1
    bpl.s    labLAAD    | branch if > 0

    move.l    %d2,%d0    | get x back
    addq.w    #4,%a0    | next entry
    addq.l    #1,%d4    | next i
    lsr.l    #1,%d3    | /2
    beq     labLOCX    | branch y1 = 0

    dbf    %d5,labLOLP    | decrement and loop if not done

            | now sort out the result
labLOCX:
    add.l    %d6,%d6    | |2
    move.l    %d6,%d0    | setup for d7 = 0
labLONN:
    move.l    %d0,%d4    | save cordic result
    moveq    #0,%d5    | set default exponent sign
    tst.l    %d7    | check original exponent sign
    beq     labLOXO    | branch if original was 0

    bpl.s    labLOXP    | branch if was +ve

    neg.l    %d7    | make original exponent +ve
    moveq    #0x80-0x100,%d5    | make sign -ve
labLOXP:
    move.b    %d5,%a3@(FAC1_s)    | save original exponent sign
    swap    %d7    | 16 bit shift
    lsl.l    #8,%d7    | easy first part
    moveq    #0x88-0x100,%d5    | start with byte
labLONE:
    subq.l    #1,%d5    | decrement exponent
    add.l    %d7,%d7    | shift mantissa
    bpl.s    labLONE    | loop if not normal

labLOXO:
    move.l    %d7,%a3@(FAC1_m)    | save original exponent as mantissa
    move.b    %d5,%a3@(FAC1_e)    | save exponent for this
    move.l    #0xB17217F8,%a3@(FAC2_m)    | LOG(2) mantissa
    move.w    #0x8000,%a3@(FAC2_e)    | LOG(2) exponent & sign
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | make sign compare = FAC1 sign
    bsr      labMULTIPLY    | do multiply
    move.l    %d4,%a3@(FAC2_m)    | save cordic result
    beq     labLOWZ    | branch if zero

    move.w    #0x8200,%a3@(FAC2_e)    | set exponent & sign
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | clear sign compare
    bsr    labADD    | and add for final result

labLOWZ:
    rts


|************************************************************************************
|
| multiply FAC1 by FAC2

|labMULTIPLY:
|    FPUTEST                    | check for FPU
|    beq     .labMULT_NOFPU    | if no FPU then emulate
|    FAC2toD0                | get FAC2
|    fmove.s    %d0,%fp0            | and copy to %fp0
|    FAC1toD0                | get FAC1
|    FSGLMUL.s    %d0,%fp0            | FAC1 * FAC2
|    fmove.s    %fp0,%d0            | get result in D0
|    D0toFAC1                | and save in FAC1
|    rts

labMULTIPLY:
    FPUTEST                             | check for FPU
    beq     .labMULT_NOFPU              | if no FPU then emulate
    cmp.w   #0xA000,%a3@(FAC2_e)        | check if FAC2 is integer
    beq     labMULTF2Int                | FAC2 is integer
    FAC2toD0                            | fetch FAC2 as sfloat
    fmove.s %d0,%fp0                    | send FAC2 to FPU as sfloat
    bra.s   labMULTF1                   | go load FAC1
labMULTF2Int:
    fmove.l %a3@(FAC2_m),%fp0           | fetch FAC2 as integer
labMULTF1:
    cmp.w   #0xA000,%a3@(FAC1_e)        | check if FAC1 is integer
    beq     labMULTF1Int                | FAC1 is integer
    FAC1toD0                            | fetch FAC1 as sfloat
    fmul.s  %d0,%fp0                    | multiply FAC2 by FAC1 as sfloat
labMULTend:
    fmove.s %fp0,%d0                    | get result from FPU
    D0toFAC1                            | save result in FAC1
    rts
labMULTF1Int:
    fmul.l  %a3@(FAC1_m),%fp0           | multiply FAC2 by FAC1 as integer
    bra     labMULTend

.labMULT_NOFPU:
    movem.l    %d0-%d4,%sp@-    | save registers
    tst.b    %a3@(FAC1_e)    | test FAC1 exponent
    beq     labMUUF    | if exponent zero go make result zero

    move.b    %a3@(FAC2_e),%d0    | get FAC2 exponent
    beq     labMUUF    | if exponent zero go make result zero

    move.b    %a3@(FAC_sc),%a3@(FAC1_s)    | sign compare becomes sign

    add.b    %a3@(FAC1_e),%d0    | multiply exponents by adding
    bcc      labMNOC    | branch if no carry

    sub.b    #0x80,%d0    | normalise result
    bcc    labOFER    | if no carry do overflow

    bra      labMadd    | branch

            | no carry for exponent add
labMNOC:
    sub.b    #0x80,%d0    | normalise result
    bcs.s    labMUUF    | return zero if underflow

labMadd:
    move.b    %d0,%a3@(FAC1_e)    | save exponent

            | d1 (FAC1) x d2 (FAC2)
    move.l    %a3@(FAC1_m),%d1    | get FAC1 mantissa
    move.l    %a3@(FAC2_m),%d2    | get FAC2 mantissa

    move.w    %d1,%d4    | copy low word FAC1
    move.l    %d1,%d0    | copy long word FAC1
    swap    %d0    | high word FAC1 to low word FAC1
    move.w    %d0,%d3    | copy high word FAC1

    MULU    %d2,%d1    | low word FAC2 x low word FAC1
    MULU    %d2,%d0    | low word FAC2 x high word FAC1
    swap    %d2    | high word FAC2 to low word FAC2
    MULU    %d2,%d4    | high word FAC2 x low word FAC1
    MULU    %d2,%d3    | high word FAC2 x high word FAC1

| done multiply, now add partial products

|    d1 =    aaaa    ----    FAC2_L x FAC1_L
|    d0 =    bbbb    aaaa    FAC2_L x FAC1_H
|    d4 =    bbbb    aaaa    FAC2_H x FAC1_L
|    d3 =    cccc    bbbb    FAC2_H x FAC1_H
|    product =    mmmm    mmmm

    add.L    #0x8000,%d1    | round up lowest word
    clr.w    %d1    | clear low word, do not need it
    swap    %d1    | align high word
    add.l    %d0,%d1    | add FAC2_L x FAC1_H (cannot be carry)
labMUF1:
    add.l    %d4,%d1    | now add intermediate (FAC2_H x FAC1_L)
    bcc      labMUF2    | branch if no carry

    add.l    #0x10000,%d3    | else correct result
labMUF2:
    add.l    #0x8000,%d1    | round up low word
    clr.w    %d1    | clear low word
    swap    %d1    | align for final add
    add.l    %d3,%d1    | add FAC2_H x FAC1_H, result
    bmi      labMUF3    | branch if normalisation not needed

    add.l    %d1,%d1    | shift mantissa
    subq.b    #1,%a3@(FAC1_e)    | adjust exponent
    beq     labMUUF    | branch if underflow

labMUF3:
    move.l    %d1,%a3@(FAC1_m)    | save mantissa
labMUEX:
    movem.l    %sp@+,%d0-%d4    | restore registers
    rts
            | either zero or underflow result
labMUUF:
    moveq    #0,%d0    | quick clear
    move.l    %d0,%a3@(FAC1_m)    | clear mantissa
    move.w    %d0,%a3@(FAC1_e)    | clear sign and exponent
    bra      labMUEX    | restore regs & exit


|************************************************************************************
|
| do FAC2/FAC1, result in FAC1
| fast hardware divide version

|labDIVIDE:
|    FPUTEST                    | check FPU presence
|    beq     .labDIV_NOFPU    | emulate if no FPU
|    FAC1toD0                | get FAC1 in D0
|    fmove.s    %d0,%fp0            | and copy to %fp0
|    FAC2toD0                | get FAC2 in D0
|    FSGLDIV.s    %d0,%fp0            | FAC2/FAC1
|    fmove.s    %fp0,%d0            | get result in D0
|    D0toFAC1                | and save result in FAC1
|    rts

labDIVIDE:
    FPUTEST                             | check for FPU
    beq     .labDIV_NOFPU               | emulate if no FPU
    cmp.w   #0xA000,%a3@(FAC1_e)        | check if FAC1 is integer
    beq     labDIVF1Int                 | FAC1 is integer
    FAC1toD0                            | get FAC1 in D0 as sfloat
    fmove.s %d0,%fp0                    | send FAC1 to FPU as sfloat
    bra.s   labDIVF2                    | go fetch FAC2
labDIVF1Int:
    fmove.l %a3@(FAC1_m),%fp0           | send FAC1 to FPU as integer
labDIVF2:
    cmp.w   #0xA000,%a3@(FAC2_e)        | check if FAC2 is integer
    beq     labDIVF2Int                 | FAC2 is integer
    FAC2toD0                            | fetch FAC2 as sfloat
    fdiv.s  %d0,%fp0                    | divide FAC2 as sfloat from FAC1
labDIVend:
    fmove.s %fp0,%d0                    | get result from FPU
    D0toFAC1                            | save result in FAC1
    rts
labDIVF2Int:
    fdiv.l  %a3@(FAC2_m),%fp0           | divide FAC2 as integer from FAC1
    bra     labDIVend


.labDIV_NOFPU:
    move.l    %d7,%sp@-    | save d7
    moveq    #0,%d0    | clear FAC2 exponent
    move.l    %d0,%d2    | clear FAC1 exponent

    move.b    %a3@(FAC1_e),%d2    | get FAC1 exponent
    beq    labDZER    | if zero go do /0 error

    move.b    %a3@(FAC2_e),%d0    | get FAC2 exponent
    beq     labDIV0    | if zero return zero

    sub.w    %d2,%d0    | get result exponent by subtracting
    add.w    #0x80,%d0    | correct 16 bit exponent result

    move.b    %a3@(FAC_sc),%a3@(FAC1_s)    | sign compare is result sign

| now to do 32/32 bit mantissa divide

    clr.b    %a3@(flag)    | clear 'flag' byte
    move.l    %a3@(FAC1_m),%d3    | get FAC1 mantissa
    move.l    %a3@(FAC2_m),%d4    | get FAC2 mantissa
    cmp.l    %d3,%d4    | compare FAC2 with FAC1 mantissa
    beq     labMAN1    | set mantissa result = 1 if equal

    bcs.s    AC1gtAC2    | branch if FAC1 > FAC2

    sub.l    %d3,%d4    | subtract FAC1 from FAC2, result now must be <1
    addq.b    #3,%a3@(flag)    | FAC2>FAC1 so set 'flag' byte
AC1gtAC2:
    bsr      lab32_16    | do 32/16 divide
    swap    %d1    | move 16 bit result to high word
    move.l    %d2,%d4    | copy remainder longword
    bsr      lab3216    | do 32/16 divide again (skip copy d4 to d2)
    DIVU.w    %d5,%d2    | now divide remainder to make guard word
    move.b    %a3@(flag),%d7    | now normalise, get flag byte back
    beq     labDIVX    | skip add if null

| else result was >1 so we need to add 1 to result mantissa and adjust exponent

    lsr.b    #1,%d7    | shift 1 into eXtend
    roxr.l    #1,%d1    | shift extend result >>
    roxr.w    #1,%d2    | shift extend guard word >>
    addq.b    #1,%d0    | adjust exponent

| now round result to 32 bits

labDIVX:
    add.w    %d2,%d2    | guard bit into eXtend bit
    bcc      L_DIVRND    | branch if guard=0

    addq.l    #1,%d1    | add guard to mantissa
    bcc      L_DIVRND    | branch if no overflow

labSET1:
    roxr.l    #1,%d1    | shift extend result >>
    addq.w    #1,%d0    | adjust exponent

            | test for over/under flow
L_DIVRND:
    move.w    %d0,%d3    | copy exponent
    bmi      labDIV0    | if -ve return zero

    andi.w    #0xFF00,%d3    | mask word high byte
    bne    labOFER    | branch if overflow

            | move result into FAC1
labXDIV:
    move.l    %sp@+,%d7    | restore d7
    move.b    %d0,%a3@(FAC1_e)    | save result exponent
    move.l    %d1,%a3@(FAC1_m)    | save result mantissa
    rts

| FAC1 mantissa = FAC2 mantissa so set result mantissa

labMAN1:
    moveq    #1,%d1    | set bit
    lsr.l    %d1,%d1    | bit into eXtend
    bra      labSET1    | set mantissa, adjust exponent and exit

| result is zero

labDIV0:
    moveq    #0,%d0    | zero exponent & sign
    move.l    %d0,%d1    | zero mantissa
    bra    labXDIV    | exit divide

| divide 16 bits into 32, AB/Ex
|
| d4    AAAA    BBBB    | 32 bit numerator
| d3    EEEE    xxxx    | 16 bit denominator
|
| returns -
|
| d1    xxxx    DDDD    | 16 bit result
| d2    HHHH    IIII    | 32 bit remainder

lab32_16:
    move.l    %d4,%d2    | copy FAC2 mantissa    (AB)
lab3216:
    move.l    %d3,%d5    | copy FAC1 mantissa    (EF)
    clr.w    %d5    | clear low word d1    (Ex)
    swap    %d5    | swap high word to low word    (xE)

| d3    EEEE    FFFF    | denominator copy
| d5    0000    EEEE    | denominator high word
| d2    AAAA    BBBB    | numerator copy
| d4    AAAA    BBBB    | numerator

    DIVU.w    %d5,%d4    | do FAC2/FAC1 high word    (AB/E)
    BVC.s    labLT_1    | if no overflow DIV was ok

    moveq    #-1,%d4    | else set default value

| done the divide, now check the result, we have ...

| d3    EEEE    FFFF    | denominator copy
| d5    0000    EEEE    | denominator high word
| d2    AAAA    BBBB    | numerator copy
| d4    MMMM    DDDD    | result MOD and DIV

labLT_1:
    move.w    %d4,%d6    | copy 16 bit result
    move.w    %d4,%d1    | copy 16 bit result again

| we now have ..
| d3    EEEE    FFFF    | denominator copy
| d5    0000    EEEE    | denominator high word
| d6    xxxx    DDDD    | result DIV copy
| d1    xxxx    DDDD    | result DIV copy
| d2    AAAA    BBBB    | numerator copy
| d4    MMMM    DDDD    | result MOD and DIV

| now multiply out 32 bit denominator by 16 bit result
| QRS = AB*D

    MULU.w    %d3,%d6    | FFFF | DDDD =    rrrr    SSSS
    MULU.w    %d5,%d4    | EEEE | DDDD = QQQQ    rrrr

| we now have ..
| d3    EEEE    FFFF    | denominator copy
| d5    0000    EEEE    | denominator high word
| d6    rrrr    SSSS    | 48 bit result partial low
| d1    xxxx    DDDD    | result DIV copy
| d2    AAAA    BBBB    | numerator copy
| d4    QQQQ    rrrr    | 48 bit result partial

    move.w    %d6,%d7    | copy low word of low multiply

| d7    xxxx    SSSS    | 48 bit result partial low

    clr.w    %d6    | clear low word of low multiply
    swap    %d6    | high word of low multiply to low word

| d6    0000    rrrr    | high word of 48 bit result partial low

    add.l    %d6,%d4

| d4    QQQQ    RRRR    | 48 bit result partial high longword

    moveq    #0,%d6    | clear to extend numerator to 48 bits

| now do GHI = AB0 - QRS (which is the remainder)

    sub.w    %d7,%d6    | low word subtract

| d6    xxxx    IIII    | remainder low word

    subX.l    %d4,%d2    | high longword subtract

| d2    GGGG    HHHH    | remainder high longword

| now if we got the divide correct then the remainder high longword will be +ve

    bpl.s    L_DDIV    | branch if result is ok (<needed)

| remainder was -ve so DDDD is too big

labREMM:
    subq.w    #1,%d1    | adjust DDDD

| d3    xxxx    FFFF    | denominator copy
| d6    xxxx    IIII    | remainder low word

    add.w    %d3,%d6    | add EF*1 low remainder low word

| d5    0000    EEEE    | denominator high word
| d2    GGGG    HHHH    | remainder high longword

    addX.l    %d5,%d2    | add extend EF*1 to remainder high longword
    bmi      labREMM    | loop if result still too big

| all done and result correct or <

L_DDIV:
    swap    %d2    | remainder mid word to high word

| d2    HHHH    GGGG    | (high word /should/ be 0x0000)

    move.w    %d6,%d2    | remainder in high word

| d2    HHHH    IIII    | now is 32 bit remainder
| d1    xxxx    DDDD    | 16 bit result

    rts


|************************************************************************************
|
| unpack memory %a0@ into FAC1

labUFAC:
    move.l    %a0@,%d0    | get packed value
    swap    %d0    | exponent and sign into least significant word
    move.w    %d0,%a3@(FAC1_e)    | save exponent and sign
    beq     labNB1T    | branch if exponent (and the rest) zero

    OR.w    #0x80,%d0    | set MSb
    swap    %d0    | word order back to normal
    ASL.l    #8,%d0    | shift exponent & clear guard byte
labNB1T:
    move.l    %d0,%a3@(FAC1_m)    | move into FAC1

    move.b    %a3@(FAC1_e),%d0    | get FAC1 exponent
    rts


|************************************************************************************
|
| set numeric variable, pack FAC1 into Lvarpl

labPFAC:
    move.l    %a0,%sp@-    | save pointer
    movea.l    %a3@(Lvarpl),%a0    | get destination pointer
    btst    #6,%a3@(Dtypef)    | test data type
    beq     lab277C    | branch if floating

    bsr    lab2831    | convert FAC1 floating to fixed
            | result in d0 and Itemp
    move.l    %d0,%a0@    | save in var
    move.l    %sp@+,%a0    | restore pointer
    rts


|************************************************************************************
|
| normalise round and pack FAC1 into %a0@

lab2778:
    move.l    %a0,%sp@-    | save pointer
lab277C:
    bsr    lab24D5    | normalise FAC1
    bsr      lab27BA    | round FAC1
    move.l    %a3@(FAC1_m),%d0    | get FAC1 mantissa
    ror.l    #8,%d0    | align 24/32 bit mantissa
    swap    %d0    | exponent/sign into 0-15
    and.w    #0x7F,%d0    | clear exponent and sign bit
    andi.b    #0x80,%a3@(FAC1_s)    | clear non sign bits in sign
    OR.w    %a3@(FAC1_e),%d0    | OR in exponent and sign
    swap    %d0    | move exponent and sign back to 16-31
    move.l    %d0,%a0@    | store in destination
    move.l    %sp@+,%a0    | restore pointer
    rts


|************************************************************************************
|
| copy FAC2 to FAC1

lab279B:
    move.w    %a3@(FAC2_e),%a3@(FAC1_e)    | copy exponent & sign
    move.l    %a3@(FAC2_m),%a3@(FAC1_m)    | copy mantissa
    rts


|************************************************************************************
|
| round FAC1

lab27BA:
    move.b    %a3@(FAC1_e),%d0    | get FAC1 exponent
    beq     lab27C4    | branch if zero

    move.l    %a3@(FAC1_m),%d0    | get FAC1
    add.l    #0x80,%d0    | round to 24 bit
    bcc      lab27C3    | branch if no overflow

    roxr.l    #1,%d0    | shift FAC1 mantissa
    addq.b    #1,%a3@(FAC1_e)    | correct exponent
    bcs    labOFER    | if carry do overflow error & warm start

lab27C3:
    and.b    #0x00,%d0    | clear guard byte
    move.l    %d0,%a3@(FAC1_m)    | save back to FAC1
    rts

lab27C4:
    move.b    %d0,%a3@(FAC1_s)    | make zero always +ve
rts_017:
    rts


|************************************************************************************
|
| get FAC1 sign
| return d0=-1,C=1/-ve d0=+1,C=0/+ve

lab27CA:
    moveq    #0,%d0    | clear d0
    move.b    %a3@(FAC1_e),%d0    | get FAC1 exponent
    beq     rts_017    | exit if zero (already correct SGN(0)=0)


|************************************************************************************
|
| return d0=-1,C=1/-ve d0=+1,C=0/+ve
| no = 0 check

lab27CE:
    move.b    %a3@(FAC1_s),%d0    | else get FAC1 sign (b7)


|************************************************************************************
|
| return d0=-1,C=1/-ve d0=+1,C=0/+ve
| no = 0 check, sign in d0

lab27D0:
    ext.w    %d0    | make word
    ext.l    %d0    | make longword
    ASR.l    #8,%d0    | move sign bit through byte to carry
    bcs.s    rts_017    | exit if carry set

    moveq    #1,%d0    | set result for +ve sign
    rts


|************************************************************************************
|
| perform SGN()

labSGN:
    bsr      lab27CA    | get FAC1 sign
            | return d0=-1/-ve d0=+1/+ve


|************************************************************************************
|
| save d0 as integer longword

lab27DB:
    move.l  %d0,%a3@(FAC1_m)            | save FAC1 mantissa
    move.w  #0xA000,%a3@(FAC1_e)        | set FAC1 exponent & sign
    add.l   %d0,%d0                     | top bit into carry
    bra     lab24D0                     | do +/- (carry is sign) & normalise FAC1


|************************************************************************************
|
| perform ABS()

labABS:
    move.b    #0,%a3@(FAC1_s)    | clear FAC1 sign
    rts


|************************************************************************************
|
| compare FAC1 with FAC2
| returns d0=+1 Cb=0 if FAC1 > FAC2
| returns d0= 0 Cb=0 if FAC1 = FAC2
| returns d0=-1 Cb=1 if FAC1 < FAC2

lab27FA:
    move.b    %a3@(FAC2_e),%d1    | get FAC2 exponent
    beq     lab27CA    | branch if FAC2 exponent=0 & get FAC1 sign
            | d0=-1,C=1/-ve d0=+1,C=0/+ve

    move.b    %a3@(FAC_sc),%d0    | get FAC sign compare
    bmi      lab27CE    | if signs <> do return d0=-1,C=1/-ve
            | d0=+1,C=0/+ve & return

    move.b    %a3@(FAC1_s),%d0    | get FAC1 sign
    cmp.b    %a3@(FAC1_e),%d1    | compare FAC1 exponent with FAC2 exponent
    bne.s    lab2828    | branch if different

    move.l    %a3@(FAC2_m),%d1    | get FAC2 mantissa
    cmp.l    %a3@(FAC1_m),%d1    | compare mantissas
    beq     lab282F    | exit if mantissas equal

| gets here if number <> FAC1

lab2828:
    bcs.s    lab27D0    | if FAC1 > FAC2 return d0=-1,C=1/-ve d0=+1,
            | C=0/+ve

    eori.b    #0x80,%d0    | else toggle FAC1 sign
lab282E:
    bra      lab27D0    | return d0=-1,C=1/-ve d0=+1,C=0/+ve

lab282F:
    moveq    #0,%d0    | clear result
    rts


|************************************************************************************
|
| convert FAC1 floating to fixed
| result in d0 and Itemp, sets flags correctly

lab2831:
    move.l    %a3@(FAC1_m),%d0    | copy mantissa
    beq     lab284J    | branch if mantissa = 0

    move.l    %d1,%sp@-    | save d1
    move.l    #0xa0,%d1    | set for no floating bits
    sub.b    %a3@(FAC1_e),%d1    | subtract FAC1 exponent
    bcs    labOFER    | do overflow if too big

    bne.s    lab284G    | branch if exponent was not 0xA0

    tst.b    %a3@(FAC1_s)    | test FAC1 sign
    bpl.s    lab284H    | branch if FAC1 +ve

    neg.l    %d0
    BVS.s    lab284H    | branch if was 0x80000000

    bra    labOFER    | do overflow if too big

lab284G:
    cmp.b    #0x20,%d1    | compare with minimum result for integer
    bcs.s    lab284L    | if < minimum just do shift

    moveq    #0,%d0    | else return zero
lab284L:
    lsr.l    %d1,%d0    | shift integer

    tst.b    %a3@(FAC1_s)    | test FAC1 sign (b7)
    bpl.s    lab284H    | branch if FAC1 +ve

    neg.l    %d0    | negate integer value
lab284H:
    move.l    %sp@+,%d1    | restore d1
lab284J:
    move.l    %d0,%a3@(Itemp)    | save result to Itemp
    rts


|************************************************************************************
|
| perform INT()

labINT:
    move.l    #0xa0,%d0    | set for no floating bits
    sub.b    %a3@(FAC1_e),%d0    | subtract FAC1 exponent
    bls.s    labIrts    | exit if exponent >= 0xA0
            | (too big for fraction part!)

    cmp.b    #0x20,%d0    | compare with minimum result for integer
    bcc    labPOZE    | if >= minimum go return 0
            | (too small for integer part!)

    moveq    #-1,%d1    | set integer mask
    ASL.l    %d0,%d1    | shift mask [8+2*d0]
    and.l    %d1,%a3@(FAC1_m)    | mask mantissa
labIrts:
    rts


|************************************************************************************
|
| print " in line [LINE #]"

lab2953:
    lea    %pc@(labLMSG),%a0    | point to " in line " message
    bsr    lab18C3    | print null terminated string

            | Print Basic line #
    move.l    %a3@(Clinel),%d0    | get current line


|************************************************************************************
|
| print d0 as unsigned integer

lab295E:
    lea    %pc@(Bin2dec),%a1    | get table address
    moveq    #0,%d1    | table index
    lea    %a3@(Usdss),%a0    | output string start
    move.l    %d1,%d2    | output string index
lab2967:
    move.l    (%a1,%d1.w),%d3    | get table value
    beq     lab2969    | exit if end marker

    moveq    #'0'-1,%d4    | set character to "0"-1
lab2968:
    addq.w    #1,%d4    | next numeric character
    sub.l    %d3,%d0    | subtract table value
    bpl.s    lab2968    | not overdone so loop

    add.l    %d3,%d0    | correct value
    move.b    %d4,(%a0,%d2.w)    | character out to string
    addq.w    #4,%d1    | increment table pointer
    addq.w    #1,%d2    | increment output string pointer
    bra      lab2967    | loop

lab2969:
    add.b    #'0',%d0    | make last character
    move.b    %d0,(%a0,%d2.w)    | character out to string
    subq.w    #1,%a0    | decrement a0 (allow simple loop)

            | now find non zero start of string
lab296A:
    addq.w    #1,%a0    | increment a0 (this will never carry to b16)
    lea    %a3@(BHsend-1),%a1    | get string end
    cmpA.l    %a1,%a0    | are we at end
    beq    lab18C3    | if so print null terminated string and RETURN

    cmpi.b    #'0',%a0@    | is character "0" ?
    beq     lab296A    | loop if so

    bra    lab18C3    | print null terminated string from memory & RET


|************************************************************************************
|
| convert FAC1 to ASCII string result in %a0@
| STR$() function enters here

| now outputs 7 significant digits

| d0 is character out
| d1 is save index
| d2 is gash

| a0 is output string pointer

lab2970:
    lea    %a3@(Decss),%a1    | set output string start

    moveq    #' ',%d2    | character = " ", assume +ve
    Bclr.b    #7,%a3@(FAC1_s)    | test and clear FAC1 sign (b7)
    beq     lab2978    | branch if +ve

    moveq    #'-',%d2    | else character = "-"
lab2978:
    move.b    %d2,%a1@    | save the sign character
    move.b    %a3@(FAC1_e),%d2    | get FAC1 exponent
    bne.s    lab2989    | branch if FAC1<>0

            | exponent was 0x00 so FAC1 is 0
    moveq    #'0',%d0    | set character = "0"
    moveq    #1,%d1    | set output string index
    bra    lab2A89    | save last character, [EOT] & exit

            | FAC1 is some non zero value
lab2989:
    move.b    #0,%a3@(numexp)    | clear number exponent count
    cmp.b    #0x81,%d2    | compare FAC1 exponent with 0x81 (>1.00000)

    bcc      lab299C    | branch if FAC1=>1

            | else FAC1 < 1
    move.l    #0x98968000,%a3@(FAC2_m)    | 10000000 mantissa
    move.w    #0x9800,%a3@(FAC2_e)    | 10000000 exponent & sign
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | make FAC1 sign sign compare
    bsr    labMULTIPLY    | do FAC2*FAC1

    move.b    #0xF9,%a3@(numexp)    | set number exponent count (-7)
    bra      lab299C    | go test for fit

lab29B9:
    move.w    %a3@(FAC1_e),%a3@(FAC2_e)    | copy exponent & sign from FAC1 to FAC2
    move.l    %a3@(FAC1_m),%a3@(FAC2_m)    | copy FAC1 mantissa to FAC2 mantissa
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | save FAC1_s as sign compare

    move.l    #0xCCCCCCCD,%a3@(FAC1_m)    | 1/10 mantissa
    move.w    #0x7D00,%a3@(FAC1_e)    | 1/10 exponent & sign
    bsr    labMULTIPLY    | do FAC2*FAC1, effectively divide by 10 but
            | faster

    addq.b    #1,%a3@(numexp)    | increment number exponent count
lab299C:
    move.l    #0x98967F70,%a3@(FAC2_m)    | 9999999.4375 mantissa
    move.w    #0x9800,%a3@(FAC2_e)    | 9999999.4375 exponent & sign
            | (max before scientific notation)
    bsr    lab27F0    | fast compare FAC1 with FAC2
            | returns d0=+1 C=0 if FAC1 > FAC2
            | returns d0= 0 C=0 if FAC1 = FAC2
            | returns d0=-1 C=1 if FAC1 < FAC2
    BHI.s    lab29B9    | go do /10 if FAC1 > 9999999.4375

    beq     lab29C3    | branch if FAC1 = 9999999.4375

            | FAC1 < 9999999.4375
    move.l    #0xF423F800,%a3@(FAC2_m)    | set mantissa for 999999.5
    move.w    #0x9400,%a3@(FAC2_e)    | set exponent for 999999.5

    lea    %a3@(FAC1_m),%a0    | set pointer for x10
lab29A7:
    bsr    lab27F0    | fast compare FAC1 with FAC2
            | returns d0=+1 C=0 if FAC1 > FAC2
            | returns d0= 0 C=0 if FAC1 = FAC2
            | returns d0=-1 C=1 if FAC1 < FAC2
    BHI.s    lab29C0    | branch if FAC1 > 99999.9375,no decimal places

            | FAC1 <= 999999.5 so do x 10
    move.l    %a0@,%d0    | get FAC1 mantissa
    move.b    %a0@(4),%d1    | get FAC1 exponent
    move.l    %d0,%d2    | copy it
    lsr.l    #2,%d0    | /4
    add.l    %d2,%d0    | add FAC1 (x1.125)
    bcc      lab29B7    | branch if no carry

    roxr.l    #1,%d0    | shift carry back in
    addq.b    #1,%d1    | increment exponent (never overflows)
lab29B7:
    addq.b    #3,%d1    | correct exponent ( 8 x 1.125 = 10 )
            | (never overflows)
    move.l    %d0,%a0@    | save new mantissa
    move.b    %d1,%a0@(4)    | save new exponent
    subq.b    #1,%a3@(numexp)    | decrement number exponent count
    bra      lab29A7    | go test again

            | now we have just the digits to do
lab29C0:
    move.l    #0x80000000,%a3@(FAC2_m)    | set mantissa for 0.5
    move.w    #0x8000,%a3@(FAC2_e)    | set exponent for 0.5
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | sign compare = sign
    bsr    labADD    | add the 0.5 to FAC1 (round FAC1)

lab29C3:
    bsr    lab2831    | convert FAC1 floating to fixed
            | result in d0 and Itemp
    moveq    #0x01,%d2    | set default digits before dp = 1
    move.b    %a3@(numexp),%d0    | get number exponent count
    add.b    #8,%d0    | allow 7 digits before point
    bmi      lab29D9    | if -ve then 1 digit before dp

    cmp.b    #0x09,%d0    | d0>=9 if n>=1E7
    bcc      lab29D9    | branch if >= 0x09

            | < 0x08
    subq.b    #1,%d0    | take 1 from digit count
    move.b    %d0,%d2    | copy byte
    moveq    #0x02,%d0    | set exponent adjust
lab29D9:
    moveq    #0,%d1    | set output string index
    subq.b    #2,%d0    | -2
    move.b    %d0,%a3@(expcnt)    | save exponent adjust
    move.b    %d2,%a3@(numexp)    | save digits before dp count
    move.b    %d2,%d0    | copy digits before dp count
    beq     lab29E4    | branch if no digits before dp

    bpl.s    lab29F7    | branch if digits before dp

lab29E4:
    addq.l    #1,%d1    | increment index
    move.b    #'.',(%a1,%d1.w)    | save to output string

    tst.b    %d2    | test digits before dp count
    beq     lab29F7    | branch if no digits before dp

    addq.l    #1,%d1    | increment index
    move.b    #'0',(%a1,%d1.w)    | save to output string
lab29F7:
    moveq    #0,%d2    | clear index (point to 1,000,000)
    moveq    #0x80-0x100,%d0    | set output character
lab29FB:
    lea    %pc@(lab2A9A),%a0    | get base of table
    move.l    (%a0,%d2.w),%d3    | get table value
lab29FD:
    addq.b    #1,%d0    | increment output character
    add.l    %d3,%a3@(Itemp)    | add to (now fixed) mantissa
    btst    #7,%d0    | set test sense (z flag only)
    bcs.s    lab2A18    | did carry so has wrapped past zero

    beq     lab29FD    | no wrap and +ve test so try again

    bra      lab2A1A    | found this digit

lab2A18:
    bne.s    lab29FD    | wrap and -ve test so try again

lab2A1A:
    bcc      lab2A21    | branch if +ve test result

    neg.b    %d0    | negate the digit number
    add.b    #0x0B,%d0    | and subtract from 11 decimal
lab2A21:
    add.b    #0x2F,%d0    | add "0"-1 to result
    addq.w    #4,%d2    | increment index to next less power of ten
    addq.w    #1,%d1    | increment output string index
    move.b    %d0,%d3    | copy character to d3
    and.b    #0x7F,%d3    | mask out top bit
    move.b    %d3,(%a1,%d1.w)    | save to output string
    sub.b    #1,%a3@(numexp)    | decrement # of characters before the dp
    bne.s    lab2A3B    | branch if still characters to do

            | else output the point
    addq.l    #1,%d1    | increment index
    move.b    #'.',(%a1,%d1.w)    | save to output string
lab2A3B:
    and.b    #0x80,%d0    | mask test sense bit
    eori.b    #0x80,%d0    | invert it
    cmp.b    #lab2A9B-lab2A9A,%d2    | compare table index with max+4
    bne.s    lab29FB    | loop if not max

            | now remove trailing zeroes
lab2A4B:
    move.b    (%a1,%d1.w),%d0    | get character from output string
    subq.l    #1,%d1    | decrement output string index
    cmp.b    #'0',%d0    | compare with "0"
    beq     lab2A4B    | loop until non "0" character found

    cmp.b    #'.',%d0    | compare with "."
    beq     lab2A58    | branch if was dp

            | else restore last character
    addq.l    #1,%d1    | increment output string index
lab2A58:
    move.b    #'+',2(%a1,%d1.w)    | save character "+" to output string
    tst.b    %a3@(expcnt)    | test exponent count
    beq     lab2A8C    | if zero go set null terminator & exit

            | exponent is not zero so write exponent
    bpl.s    lab2A68    | branch if exponent count +ve

    move.b    #'-',2(%a1,%d1.w)    | save character "-" to output string
    neg.b    %a3@(expcnt)    | convert -ve to +ve
lab2A68:
    move.b    #'E',1(%a1,%d1.w)    | save character "E" to output string
    move.b    %a3@(expcnt),%d2    | get exponent count
    moveq    #0x2F,%d0    | one less than "0" character
lab2A74:
    addq.b    #1,%d0    | increment 10s character
    sub.b    #0x0A,%d2    | subtract 10 from exponent count
    bcc      lab2A74    | loop while still >= 0

    add.b    #0x3A,%d2    | add character ":", 0x30+0x0A, result is 10-value
    move.b    %d0,3(%a1,%d1.w)    | save 10s character to output string
    move.b    %d2,4(%a1,%d1.w)    | save 1s character to output string
    move.b    #0,5(%a1,%d1.w)    | save null terminator after last character
    bra      lab2A91    | go set string pointer %a0@ and exit

lab2A89:
    move.b    %d0,(%a1,%d1.w)    | save last character to output string
lab2A8C:
    move.b    #0,1(%a1,%d1.w)    | save null terminator after last character
lab2A91:
    movea.l    %a1,%a0    | set result string pointer %a0@
    rts


|************************************************************************************
|
| fast compare FAC1 with FAC2
| assumes both are +ve and FAC2>0
| returns d0=+1 C=0 if FAC1 > FAC2
| returns d0= 0 C=0 if FAC1 = FAC2
| returns d0=-1 C=1 if FAC1 < FAC2

lab27F0:
    moveq    #0,%d0    | set for FAC1 = FAC2
    move.b    %a3@(FAC2_e),%d1    | get FAC2 exponent
    cmp.b    %a3@(FAC1_e),%d1    | compare FAC1 exponent with FAC2 exponent
    bne.s    lab27F1    | branch if different

    move.l    %a3@(FAC2_m),%d1    | get FAC2 mantissa
    cmp.l    %a3@(FAC1_m),%d1    | compare mantissas
    beq     lab27F3    | exit if mantissas equal

lab27F1:
    bcs.s    lab27F2    | if FAC1 > FAC2 return d0=+1,C=0

    subq.l    #1,%d0    | else FAC1 < FAC2 return d0=-1,C=1
    rts

lab27F2:
    addq.l    #1,%d0
lab27F3:
    rts


|************************************************************************************
|
| make FAC1 = 1

labPOON:
    move.l  #0x80000000,%a3@(FAC1_m)    | 1 mantissa
    move.w  #0x8100,%a3@(FAC1_e)        | 1 exponent & sign
    rts


|************************************************************************************
|
| make FAC1 = 0

labPOZE:
    moveq   #0,%d0                      | clear longword
    move.l  %d0,%a3@(FAC1_m)            | 0 mantissa
    move.w  %d0,%a3@(FAC1_e)            | 0 exonent & sign
    rts


|************************************************************************************
|
| perform power function
| the number is in FAC2, the power is in FAC1
| no longer trashes Itemp

labPOWER:
    tst.b    %a3@(FAC1_e)    | test power
    beq     labPOON    | if zero go return 1

    tst.b    %a3@(FAC2_e)    | test number
    beq     labPOZE    | if zero go return 0

    move.b    %a3@(FAC2_s),%sp@-    | save number sign
    bpl.s    labPOWP    | power of positive number

    moveq    #0,%d1    | clear d1
    move.b    %d1,%a3@(FAC2_s)    | make sign +ve

            | number sign was -ve and can only be raised to
            | an integer power which gives an x +j0 result,
            | else do 'function call' error
    move.b    %a3@(FAC1_e),%d1    | get power exponent
    sub.w    #0x80,%d1    | normalise to .5
    bls    labFCER    | if 0<power<1 then do 'function call' error

            | now shift all the integer bits out
    move.l    %a3@(FAC1_m),%d0    | get power mantissa
    ASL.l    %d1,%d0    | shift mantissa
    bne    labFCER    | if power<>INT(power) then do 'function call'
            | error

    bcs.s    labPOWP    | if integer value odd then leave result -ve

    move.b    %d0,%sp@    | save result sign +ve
labPOWP:
    move.l    %a3@(FAC1_m),%sp@-    | save power mantissa
    move.w    %a3@(FAC1_e),%sp@-    | save power sign & exponent

    bsr    lab279B    | copy number to FAC1
    bsr    labLOG    | find log of number

    move.w    %sp@+,%d0    | get power sign & exponent
    move.l    %sp@+,%a3@(FAC2_m)    | get power mantissa
    move.w    %d0,%a3@(FAC2_e)    | save sign & exponent to FAC2
    move.b    %d0,%a3@(FAC_sc)    | save sign as sign compare
    move.b    %a3@(FAC1_s),%d0    | get FAC1 sign
    eor.b    %d0,%a3@(FAC_sc)    | make sign compare (FAC1_s eor FAC2_s)

    bsr    labMULTIPLY    | multiply by power
    bsr      labEXP    | find exponential
    move.b    %sp@+,%a3@(FAC1_s)    | restore number sign
    rts


|************************************************************************************
|
| do - FAC1

labGTHAN:
    tst.b    %a3@(FAC1_e)    | test for non zero FAC1
    beq     rts_020    | branch if null

    eori.b    #0x80,%a3@(FAC1_s)    | (else) toggle FAC1 sign bit
rts_020:
    rts


|************************************************************************************
|
            | return +1
labEX1:
    move.l    #0x80000000,%a3@(FAC1_m)    | +1 mantissa
    move.w    #0x8100,%a3@(FAC1_e)    | +1 sign & exponent
    rts
            | do over/under flow
labEXOU:
    tst.b    %a3@(FAC1_s)    | test sign
    bpl    labOFER    | was +ve so do overflow error

            | else underflow so return zero
    moveq    #0,%d0    | clear longword
    move.l    %d0,%a3@(FAC1_m)    | 0 mantissa
    move.w    %d0,%a3@(FAC1_e)    | 0 sign & exponent
    rts
            | fraction was zero so do 2^n
labEXOF:
    move.l    #0x80000000,%a3@(FAC1_m)    | +n mantissa
    move.b    #0,%a3@(FAC1_s)    | clear sign
    tst.b    %a3@(cosout)    | test sign flag
    bpl.s    labEXOL    | branch if +ve

    neg.l    %d1    | else do 1/2^n
labEXOL:
    add.b    #0x81,%d1    | adjust exponent
    move.b    %d1,%a3@(FAC1_e)    | save exponent
    rts

| perform EXP()    (x^e)
| valid input range is -88 to +88

labEXP:
    move.b    %a3@(FAC1_e),%d0    | get exponent
    beq     labEX1    | return 1 for zero in

    cmp.b    #0x64,%d0    | compare exponent with min
    bcs.s    labEX1    | if smaller just return 1

|*    movem.l    %d1-%d6/%a0,%sp@-    | save the registers
    move.b    #0,%a3@(cosout)    | flag +ve number
    move.l    %a3@(FAC1_m),%d1    | get mantissa
    cmp.b    #0x87,%d0    | compare exponent with max
    BHI.s    labEXOU    | go do over/under flow if greater

    bne.s    labEXCM    | branch if less

            | else is 2^7
    cmp.l    #0xB00F33C7,%d1    | compare mantissa with n*2^7 max
    bcc      labEXOU    | if => go over/underflow

labEXCM:
    tst.b    %a3@(FAC1_s)    | test sign
    bpl.s    labEXPS    | branch if arg +ve

    move.b    #0xFF,%a3@(cosout)    | flag -ve number
    move.b    #0,%a3@(FAC1_s)    | take absolute value
labEXPS:
            | now do n/LOG(2)
    move.l    #0xB8AA3B29,%a3@(FAC2_m)    | 1/LOG(2) mantissa
    move.w    #0x8100,%a3@(FAC2_e)    | 1/LOG(2) exponent & sign
    move.b    #0,%a3@(FAC_sc)    | we know they are both +ve
    bsr    labMULTIPLY    | effectively divide by log(2)

            | max here is +/- 127
            | now separate integer and fraction
    move.b    #0,%a3@(tpower)    | clear exponent add byte
    move.b    %a3@(FAC1_e),%d5    | get exponent
    sub.b    #0x80,%d5    | normalise
    bls.s    labESML    | branch if < 1 (d5 is 0 or -ve)

            | result is > 1
    move.l    %a3@(FAC1_m),%d0    | get mantissa
    move.l    %d0,%d1    | copy it
    move.l    %d5,%d6    | copy normalised exponent

    neg.w    %d6    | make -ve
    add.w    #32,%d6    | is now 32-d6
    lsr.l    %d6,%d1    | just integer bits
    move.b    %d1,%a3@(tpower)    | set exponent add byte

    lsl.l    %d5,%d0    | shift out integer bits
    beq    labEXOF    | fraction is zero so do 2^n

    move.l    %d0,%a3@(FAC1_m)    | fraction to FAC1
    move.w    #0x8000,%a3@(FAC1_e)    | set exponent & sign

            | multiple was < 1
labESML:
    move.l    #0xB17217F8,%a3@(FAC2_m)    | LOG(2) mantissa
    move.w    #0x8000,%a3@(FAC2_e)    | LOG(2) exponent & sign
    move.b    #0,%a3@(FAC_sc)    | clear sign compare
    bsr    labMULTIPLY    | multiply by log(2)

    move.l    %a3@(FAC1_m),%d0    | get mantissa
    move.b    %a3@(FAC1_e),%d5    | get exponent
    sub.w    #0x82,%d5    | normalise and -2 (result is -1 to -30)
    neg.w    %d5    | make +ve
    lsr.l    %d5,%d0    | shift for 2 integer bits

| d0 = arg
| d6 = x, d1 = y
| d2 = x1, d3 = y1
| d4 = shift count
| d5 = loop count
            | now do cordic set-up
    moveq    #0,%d1    | y = 0
    move.l    #KFCTSEED,%d6    | x = 1 with jkh inverse factored out
    lea    %pc@(TAB_HTHET),%a0    | get pointer to hyperbolic arctan table
    moveq    #0,%d4    | clear shift count
 
            | cordic loop, shifts 4 and 13 (and 39
            | if it went that far) need to be repeated
    moveq    #3,%d5    | 4 loops
    bsr      labEXCC    | do loops 1 through 4
    subq.w    #4,%a0    | do table entry again
    subq.l    #1,%d4    | do shift count again
    moveq    #9,%d5    | 10 loops
    bsr      labEXCC    | do loops 4 (again) through 13
    subq.w    #4,%a0    | do table entry again
    subq.l    #1,%d4    | do shift count again
    moveq    #18,%d5    | 19 loops
    bsr      labEXCC    | do loops 13 (again) through 31
 
            | now get the result
    tst.b    %a3@(cosout)    | test sign flag
    bpl.s    labEXPL    | branch if +ve

    neg.l    %d1    | do -y
    neg.b    %a3@(tpower)    | do -exp
labEXPL:
    moveq    #0x83-0x100,%d0    | set exponent
    add.l    %d1,%d6    | y = y +/- x
    bmi      labEXRN    | branch if result normal

labEXNN:
    subq.l    #1,%d0    | decrement exponent
    add.l    %d6,%d6    | shift mantissa
    bpl.s    labEXNN    | loop if not normal

labEXRN:
    move.l    %d6,%a3@(FAC1_m)    | save exponent result
    add.b    %a3@(tpower),%d0    | add integer part
    move.b    %d0,%a3@(FAC1_e)    | save exponent
|*    movem.l    %sp@+,%d1-%d6/%a0    | restore registers
    rts
 
            | cordic loop
labEXCC:
    addq.l    #1,%d4    | increment shift count
    move.l    %d6,%d2    | x1 = x
    ASR.l    %d4,%d2    | x1 >> n
    move.l    %d1,%d3    | y1 = y
    ASR.l    %d4,%d3    | y1 >> n
    tst.l    %d0    | test arg
    bmi      labEXAD    | branch if -ve

    add.l    %d2,%d1    | y = y + x1
    add.l    %d3,%d6    | x = x + y1
    sub.l    %a0@+,%d0    | arg = arg - %a0@(atnh)
    dbf    %d5,labEXCC    | decrement and loop if not done

    rts

labEXAD:
    sub.l    %d2,%d1    | y = y - x1
    sub.l    %d3,%d6    | x = x + y1
    add.l    %a0@+,%d0    | arg = arg + %a0@(atnh)
    dbf    %d5,labEXCC    | decrement and loop if not done

    rts


|************************************************************************************
|
| RND(n), 32 bit Galois version. make n=0 for 19th next number in sequence or n<>0
| to get 19th next number in sequence after seed n. This version of the PRNG uses
| the Galois method and a sample of 65536 bytes produced gives the following values.

| Entropy = 7.997442 bits per byte
| Optimum compression would reduce these 65536 bytes by 0 percent

| Chi square distribution for 65536 samples is 232.01, and
| randomly would exceed this value 75.00 percent of the time

| Arithmetic mean value of data bytes is 127.6724, 127.5 would be random
| Monte Carlo value for Pi is 3.122871269, error 0.60 percent
| Serial correlation coefficient is -0.000370, totally uncorrelated would be 0.0

labRND:
    tst.b    %a3@(FAC1_e)    | get FAC1 exponent
    beq     NextPRN    | do next random number if zero

            | else get seed into random number store
    lea    %a3@(PRNlword),%a0    | set PRNG pointer
    bsr    lab2778    | pack FAC1 into %a0@
NextPRN:
    moveq    #0xAF-0x100,%d1    | set eor value
    moveq    #18,%d2    | do this 19 times
    move.l    %a3@(PRNlword),%d0    | get current
Ninc0:
    add.l    %d0,%d0    | shift left 1 bit
    bcc      Ninc1    | branch if bit 32 not set

    eor.b    %d1,%d0    | do Galois LFSR feedback
Ninc1:
    dbf    %d2,Ninc0    | loop

    move.l    %d0,%a3@(PRNlword)    | save back to seed word
    move.l    %d0,%a3@(FAC1_m)    | copy to FAC1 mantissa
    move.w    #0x8000,%a3@(FAC1_e)    | set the exponent and clear the sign
    bra    lab24D5    | normalise FAC1 & return


|************************************************************************************
|
| cordic TAN(x) routine, TAN(x) = SIN(x)/COS(x)
| x = angle in radians

|labTAN:
|    FPUTEST                    | check FPU presence
|    beq     .labTAN_NOFPU    | emulate if no FPU
|    FAC1toD0                | get FAC1 in D0
|    FTAN.s    %d0,%fp0            | calculate TAN(FAC1)
|    fmove.s %fp0,%d0            | get result in D0
|    D0toFAC1                | and save in FAC1
|    rts

labTAN:
    FPUTEST                             | check for FPU
    beq     .labTAN_NOFPU               | emulate if no FPU
    cmp.w   #0xA000,%a3@(FAC1_e)        | check if FAC1 is integer
    beq     labTANF1Int                 | FAC1 is integer
    FAC1toD0                            | fetch FAC1 as sfloat
    ftan.s  %d0,%fp0                    | calculate TAN(FAC1) as sfloat
labTANend:
    fmove.s %fp0,%d0                    | get result from FPU
    D0toFAC1                            | save result in FAC1
    rts
labTANF1Int:
    ftan.l  %a3@(FAC1_m),%fp0           | calculate TAN(FAC1) as integer
    bra     labTANend


.labTAN_NOFPU:
    bsr      labSIN    | go do SIN/COS cordic compute
    move.w    %a3@(FAC1_e),%a3@(FAC2_e)    | copy exponent & sign from FAC1 to FAC2
    move.l    %a3@(FAC1_m),%a3@(FAC2_m)    | copy FAC1 mantissa to FAC2 mantissa
    move.l    %d1,%a3@(FAC1_m)    | get COS(x) mantissa
    move.b    %d3,%a3@(FAC1_e)    | get COS(x) exponent
    beq    labOFER    | do overflow if COS = 0

    bsr    lab24D5    | normalise FAC1
    bra    labDIVIDE    | do FAC2/FAC1 and return, FAC_sc set by SIN
            | COS calculation


|************************************************************************************
|
| cordic SIN(x), COS(x) routine
| x = angle in radians

|labCOS:
|    FPUTEST                    | check FPU presence
|    beq     .labCOS_NOFPU    | if no FPU then emulate
|    FAC1toD0                | get FAC1 in D0
|    FCOS.s    %d0,%fp0            | calculate COS(FAC1)
|    fmove.s %fp0,%d0            | copy result to D0
|    D0toFAC1                | save result in FAC1
|    rts

labCOS:
    FPUTEST                             | check for FPU
    beq     .labCOS_NOFPU               | emulate if no FPU
    cmp.w   #0xA000,%a3@(FAC1_e)        | check if FAC1 is integer
    beq     labCOSF1Int                 | FAC1 is integer
    FAC1toD0                            | fetch FAC1 as sfloat
    fcos.s  %d0,%fp0                    | calculate COS(FAC1) as sfloat
labCOSend:
    fmove.s %fp0,%d0                    | get result from FPU
    D0toFAC1                            | save result in FAC1
    rts
labCOSF1Int:
    fcos.l  %a3@(FAC1_m),%fp0           | calculate COS(FAC1) as integer
    bra     labCOSend


.labCOS_NOFPU:
    move.l    #0xC90FDAa3,%a3@(FAC2_m)    | pi/2 mantissa (LSB is rounded up so
            | COS(PI/2)=0)
    move.w    #0x8100,%a3@(FAC2_e)    | pi/2 exponent and sign
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | sign = FAC1 sign (b7)
    bsr    labADD    | add FAC2 to FAC1, adjust for COS(x)


|************************************************************************************
|
| SIN/COS cordic calculator

|labSIN:
|    FPUTEST                             | check FPU presence
|    beq     .labSIN_NOFPU               | if no FPU then emulate
|    FAC1toD0                            | get FAC1 in D0
|    FSIN.s  %d0,%fp0                    | calculate SIN(FAC1)
|    fmove.s %fp0,%d0                    | copy result to D0
|    D0toFAC1                            | save result in FAC1
|    rts

labSIN:
    FPUTEST                             | check for FPU
    beq     .labSIN_NOFPU               | emulate if no FPU
    cmp.w   #0xA000,%a3@(FAC1_e)        | check if FAC1 is integer
    beq     labSINF1Int                 | FAC1 is integer
    FAC1toD0                            | fetch FAC1 as sfloat
    fsin.s  %d0,%fp0                    | calculate SIN(FAC1) as sfloat
labSINend:
    fmove.s %fp0,%d0                    | get result from FPU
    D0toFAC1                            | save result in FAC1
    rts
labSINF1Int:
    fsin.l  %a3@(FAC1_m),%fp0           | calculate SIN(FAC1) as integer
    bra     labSINend


.labSIN_NOFPU:
    move.b    #0,%a3@(cosout)    | set needed result

    move.l    #0xA2F9836F,%a3@(FAC2_m)    | 1/pi mantissa (LSB is rounded up so SIN(PI)=0)
    move.w    #0x7F00,%a3@(FAC2_e)    | 1/pi exponent & sign
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | sign = FAC1 sign (b7)
    bsr    labMULTIPLY    | multiply by 1/pi

    move.b    %a3@(FAC1_e),%d0    | get FAC1 exponent
    beq     labSCZE    | branch if zero

    lea    %pc@(TAB_SNCO),%a0    | get pointer to constants table
    move.l    %a3@(FAC1_m),%d6    | get FAC1 mantissa
    subq.b    #1,%d0    | 2 radians in 360 degrees so /2
    beq     labSCZE    | branch if zero

    sub.b    #0x80,%d0    | normalise exponent
    bmi      labSCL0    | branch if < 1

            | X is > 1
    cmp.b    #0x20,%d0    | is it >= 2^32
    bcc      labSCZE    | may as well do zero

    lsl.l    %d0,%d6    | shift out integer part bits
    bne.s    labCORD    | if fraction go test quadrant and adjust

            | else no fraction so do zero
labSCZE:
    moveq    #0x81-0x100,%d2    | set exponent for 1.0
    moveq    #0,%d3    | set exponent for 0.0
    move.l    #0x80000000,%d0    | mantissa for 1.0
    move.l    %d3,%d1    | mantissa for 0.0
    bra      outloop    | go output it

            | x is < 1
labSCL0:
    neg.b    %d0    | make +ve
    cmp.b    #0x1E,%d0    | is it <= 2^-30
    bcc      labSCZE    | may as well do zero

    lsr.l    %d0,%d6    | shift out <= 2^-32 bits

| cordic calculator, argument in d6
| table pointer in %a0, returns in d0-d3

labCORD:
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | copy as sign compare for TAN
    add.l    %d6,%d6    | shift 0.5 bit into carry
    bcc      labLTPF    | branch if less than 0.5

    eori.b    #0xFF,%a3@(FAC1_s)    | toggle result sign
labLTPF:
    add.l    %d6,%d6    | shift 0.25 bit into carry
    bcc      labLTPT    | branch if less than 0.25

    eori.b    #0xFF,%a3@(cosout)    | toggle needed result
    eori.b    #0xFF,%a3@(FAC_sc)    | toggle sign compare for TAN

labLTPT:
    lsr.l    #2,%d6    | shift the bits back (clear integer bits)
    beq     labSCZE    | no fraction so go do zero

            | set start values
    moveq    #1,%d5    | set bit count
    move.l    %a0@(-4),%d0    | get multiply constant (1st itteration d0)
    move.l    %d0,%d1    | 1st itteration d1
    sub.l    %a0@+,%d6    | 1st always +ve so do 1st step
    bra      mainloop    | jump into routine

subloop:
    sub.l    %a0@+,%d6    | z = z - arctan(i)/2pi
    sub.l    %d3,%d0    | x = x - y1
    add.l    %d2,%d1    | y = y + x1
    bra      nexta    | back to main loop

mainloop:
    move.l    %d0,%d2    | x1 = x
    ASR.l    %d5,%d2    | / (2 ^ i)
    move.l    %d1,%d3    | y1 = y
    ASR.l    %d5,%d3    | / (2 ^ i)
    tst.l    %d6    | test sign (is 2^0 bit)
    bpl.s    subloop    | go do subtract if > 1

    add.l    %a0@+,%d6    | z = z + arctan(i)/2pi
    add.l    %d3,%d0    | x = x + y1
    sub.l    %d2,%d1    | y = y + x1
nexta:
    addq.l    #1,%d5    | i = i + 1
    cmp.l    #0x1E,%d5    | check end condition
    bne.s    mainloop    | loop if not all done

            | now untangle output value
    moveq    #0x81-0x100,%d2    | set exponent for 0 to .99 rec.
    move.l    %d2,%d3    | copy it for cos output
outloop:
    tst.b    %a3@(cosout)    | did we want cos output?
    bmi      subexit    | if so skip

    EXG    %d0,%d1    | swap SIN and COS mantissas
    EXG    %d2,%d3    | swap SIN and COS exponents
subexit:
    move.l    %d0,%a3@(FAC1_m)    | set result mantissa
    move.b    %d2,%a3@(FAC1_e)    | set result exponent
    bra    lab24D5    | normalise FAC1 & return



|************************************************************************************
|
| perform ATN()

|labATN:
|    FPUTEST                    | check for FPU presence
|    beq     .labATN_NOFPU    | and emulate if no FPU
|    FAC1toD0                | get FAC1
|    FATAN.s    %d0,%fp0            | calculate ARCTAN(FAC1)
|    fmove.s %fp0,%d0            | get result in D0
|    D0toFAC1                | and save in FAC1
|    rts

labATN:
    FPUTEST                             | check for FPU
    beq     .labATN_NOFPU               | emulate if no FPU
    cmp.w   #0xA000,%a3@(FAC1_e)        | check if FAC1 is integer
    beq     labATNF1Int                 | FAC1 is integer
    FAC1toD0                            | fetch FAC1 as sfloat
    fatan.s %d0,%fp0                    | calculate ATN(FAC1) as sfloat
labATNend:
    fmove.s %fp0,%d0                    | get result from FPU
    D0toFAC1                            | save result in FAC1
    rts
labATNF1Int:
    fatan.l %a3@(FAC1_m),%fp0           | calculate ATN(FAC1) as integer
    bra     labATNend


.labATN_NOFPU:
    move.b    %a3@(FAC1_e),%d0    | get FAC1 exponent
    beq    rts_021    | ATN(0) = 0 so skip calculation

    move.b    #0,%a3@(cosout)    | set result needed
    cmp.b    #0x81,%d0    | compare exponent with 1
    bcs.s    labATLE    | branch if n<1

    bne.s    labATGO    | branch if n>1

    move.l    %a3@(FAC1_m),%d0    | get mantissa
    add.l    %d0,%d0    | shift left
    beq     labATLE    | branch if n=1

labATGO:
    move.l    #0x80000000,%a3@(FAC2_m)    | set mantissa for 1
    move.w    #0x8100,%a3@(FAC2_e)    | set exponent for 1
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | sign compare = sign
    bsr    labDIVIDE    | do 1/n
    move.b    #0xFF,%a3@(cosout)    | set inverse result needed
labATLE:
    move.l    %a3@(FAC1_m),%d0    | get FAC1 mantissa
    move.l    #0x82,%d1    | set to correct exponent
    sub.b    %a3@(FAC1_e),%d1    | subtract FAC1 exponent (always <= 1)
    lsr.l    %d1,%d0    | shift in two integer part bits
    lea    %pc@(TAB_ATNC),%a0    | get pointer to arctan table
    moveq    #0,%d6    | Z = 0
    move.l    #1<<30,%d1    | y = 1
    moveq    #29,%d5    | loop 30 times
    moveq    #1,%d4    | shift counter
    bra      labATCD    | enter loop

labATNP:
    ASR.l    %d4,%d2    | x1 / 2^i
    add.l    %d2,%d1    | y = y + x1
    add.l    %a0@,%d6    | z = z + atn(i)
labATCD:
    move.l    %d0,%d2    | x1 = x
    move.l    %d1,%d3    | y1 = y
    ASR.l    %d4,%d3    | y1 / 2^i
labCATN:
    sub.l    %d3,%d0    | x = x - y1
    bpl.s    labATNP    | branch if x >= 0

    move.l    %d2,%d0    | else get x back
    addq.w    #4,%a0    | increment pointer
    addq.l    #1,%d4    | increment i
    ASR.l    #1,%d3    | y1 / 2^i
    dbf    %d5,labCATN    | decrement and loop if not done

    move.b    #0x82,%a3@(FAC1_e)    | set new exponent
    move.l    %d6,%a3@(FAC1_m)    | save mantissa
    bsr    lab24D5    | normalise FAC1

    tst.b    %a3@(cosout)    | was it > 1 ?
    bpl.s    rts_021    | branch if not

    move.b    %a3@(FAC1_s),%d7    | get sign
    move.b    #0,%a3@(FAC1_s)    | clear sign
    move.l    #0xC90FDAa2,%a3@(FAC2_m)    | set -(pi/2)
    move.w    #0x8180,%a3@(FAC2_e)    | set exponent and sign
    move.b    #0xFF,%a3@(FAC_sc)    | set sign compare
    bsr    labADD    | perform addition, FAC2 to FAC1
    move.b    %d7,%a3@(FAC1_s)    | restore sign
rts_021:
    rts


|************************************************************************************
|
| perform BITSET

labBITSET:
    bsr    labGADB    | get two parameters for POKE or WAIT
            | first parameter in %a0, second in d0
    cmp.b    #0x08,%d0    | only 0 to 7 are allowed
    bcc    labFCER    | branch if > 7

    BSET    %d0,%a0@    | set bit
    rts


|************************************************************************************
|
| perform BITCLR

labBITCLR:
    bsr    labGADB    | get two parameters for POKE or WAIT
            | first parameter in %a0, second in d0
    cmp.b    #0x08,%d0    | only 0 to 7 are allowed
    bcc    labFCER    | branch if > 7

    Bclr    %d0,%a0@    | clear bit
    rts


|************************************************************************************
|
| perform BITTST()

labBTST:
    move.b    %a5@+,%d0    | increment BASIC pointer
    bsr    labGADB    | get two parameters for POKE or WAIT
            | first parameter in %a0, second in d0
    cmp.b    #0x08,%d0    | only 0 to 7 are allowed
    bcc    labFCER    | branch if > 7

    move.l    %d0,%d1    | copy bit # to test
    bsr    labGBYT    | get next BASIC byte
    cmp.b    #')',%d0    | is next character ")"
    bne    labSNER    | if not ")" go do syntax error, then warm start

    bsr    labIGBY    | update execute pointer (to character past ")")
    moveq    #0,%d0    | set the result as zero
    btst    %d1,%a0@    | test bit
    beq    lab27DB    | branch if zero (already correct)

    moveq    #-1,%d0    | set for -1 result
    bra    lab27DB    | go do SGN tail


|************************************************************************************
|
| perform USING$()

    .equ fsd,0                            | %sp@ format string descriptor pointer
    .equ fsti,4                            | %sp@(4) format string this index
    .equ fsli,6                            | %sp@(6) format string last index
    .equ fsdpi,8                        | %sp@(8) format string decimal point index
    .equ fsdc,10                        | %sp@(10) format string decimal characters
    .equ fend,12-4                        | %sp@(x) end-4, fsd is popped by itself

    .equ ofchr,'#'                        | the overflow character

labUSINGS:
    tst.b    %a3@(Dtypef)    | test data type, 0x80=string
    bpl    labFOER    | if not string type go do format error

    movea.l    %a3@(FAC1_m),%a2    | get the format string descriptor pointer
    move.w    %a2@(4),%d7    | get the format string length
    beq    labFOER    | if null string go do format error

| clear the format string values

    moveq    #0,%d0    | clear d0
    move.w    %d0,%sp@-    | clear the format string decimal characters
    move.w    %d0,%sp@-    | clear the format string decimal point index
    move.w    %d0,%sp@-    | clear the format string last index
    move.w    %d0,%sp@-    | clear the format string this index
    move.l    %a2,%sp@-    | save the format string descriptor pointer

| make a null return string for the first string add

    moveq    #0,%d1    | make a null string
    movea.l    %d1,%a0    | with a null pointer
    bsr    labrtsT    | push a string on the descriptor stack
            | a0 = pointer, d1 = length

| do the USING$() function next value

    move.b    %a5@+,%d0    | get the next BASIC byte
labU002:
    cmp.b    #',',%d0    | compare with comma
    bne    labSNER    | if not "," go do syntax error

    bsr    labProcFo    | process the format string
    tst.b    %d2    | test the special characters flag
    beq    labFOER    | if no special characters go do format error

    bsr    labEVEX    | evaluate the expression
    tst.b    %a3@(Dtypef)    | test the data type
    bmi    labTMER    | if string type go do type missmatch error

    tst.b    %a3@(FAC1_e)    | test FAC1 exponent
    beq     labU004    | if FAC1 = 0 skip the rounding

    move.w    %sp@(fsdc),%d1    | get the format string decimal character count
    cmp.w    #8,%d1    | compare the fraction digit count with 8
    bcc      labU004    | if >= 8 skip the rounding

    move.w    %d1,%d0    | else copy the fraction digit count
    add.w    %d1,%d1    | | 2
    add.w    %d0,%d1    | | 3
    add.w    %d1,%d1    | | 6
    lea    %pc@(labP_10),%a0    | get the rounding table base
    move.l    2(%a0,%d1.w),%a3@(FAC2_m)    | get the rounding mantissa
    move.w    (%a0,%d1.w),%d0    | get the rounding exponent
    sub.w    #0x100,%d0    | effectively divide the mantissa by 2
    move.w    %d0,%a3@(FAC2_e)    | save the rounding exponent
    move.b    #0x00,%a3@(FAC_sc)    | clear the sign compare
    bsr    labADD    | round the value to n places
labU004:
    bsr    lab2970    | convert FAC1 to string - not on stack

    bsr    labDupFmt    | duplicate the processed format string section
            | returns length in %d1, pointer in a0

| process the number string, length in %d6, decimal point index in d2

    lea    %a3@(Decss),%a2    | set the number string start
    moveq    #0,%d6    | clear the number string index
    moveq    #'.',%d4    | set the decimal point character
labU005:
    move.w    %d6,%d2    | save the index to flag the decimal point
labU006:
    addq.w    #1,%d6    | increment the number string index
    move.b    (%a2,%d6.w),%d0    | get a number string character
    beq     labU010    | if null then number complete

    cmp.b    #'E',%d0    | compare the character with an "E"
    beq     labU008    | was sx[.x]Esxx so go handle sci notation

    cmp.b    %d4,%d0    | compare the character with "."
    bne.s    labU006    | if not decimal point go get the next digit

    bra      labU005    | go save the index and get the next digit

| have found an sx[.x]Esxx number, the [.x] will not be present for a single digit

labU008:
    move.w    %d6,%d3    | copy the index to the "E"
    subq.w    #1,%d3    | -1 gives the last digit index

    addq.w    #1,%d6    | increment the index to the exponent sign
    move.b    (%a2,%d6.w),%d0    | get the exponent sign character
    cmp.b    #'-',%d0    | compare the exponent sign with "-"
    bne    labFCER    | if it was not sx[.x]E-xx go do function
            | call error

| found an sx[.x]E-xx number so check the exponent magnitude

    addq.w    #1,%d6    | increment the index to the exponent 10s
    move.b    (%a2,%d6.w),%d0    | get the exponent 10s character
    cmp.b    #'0',%d0    | compare the exponent 10s with "0"
    beq     labU009    | if it was sx[.x]E-0x go get the exponent
            | 1s character

    moveq    #10,%d0    | else start writing at index 10
    bra      labU00A    | go copy the digits

| found an sx[.x]E-0x number so get the exponent magnitude

labU009:
    addq.w    #1,%d6    | increment the index to the exponent 1s
    moveq    #0x0F,%d0    | set the mask for the exponent 1s digit
    and.b    (%a2,%d6.w),%d0    | get and convert the exponent 1s digit
labU00A:
    move.w    %d3,%d2    | copy the number last digit index
    cmpi.w    #1,%d2    | is the number of the form sxE-0x
    bne.s    labU00B    | if it is sx.xE-0x skip the increment

            | else make room for the decimal point
    addq.w    #1,%d2    | add 1 to the write index
labU00B:
    add.w    %d0,%d2    | add the exponent 1s to the write index
    moveq    #10,%d0    | set the maximum write index
    sub.w    %d2,%d0    | compare the index with the maximum
    bgt.s    labU00C    | if the index < the maximum continue

    add.w    %d0,%d2    | else set the index to the maximum
    add.w    %d0,%d3    | adjust the read index
    cmpi.w    #1,%d3    | compare the adjusted index with 1
    bgt.s    labU00C    | if > 1 continue

    moveq    #0,%d3    | else allow for the decimal point
labU00C:
    move.w    %d2,%d6    | copy the write index as the number
            | string length
    moveq    #0,%d0    | clear d0 to null terminate the number
            | string
labU00D:
    move.b    %d0,(%a2,%d2.w)    | save the character to the number string
    subq.w    #1,%d2    | decrement the number write index
    cmpi.w    #1,%d2    | compare the number write index with 1
    beq     labU00F    | if at the decimal point go save it

            | else write a digit to the number string
    moveq    #'0',%d0    | default to "0"
    tst.w    %d3    | test the number read index
    beq     labU00D    | if zero just go save the "0"

labU00E:
    move.b    (%a2,%d3.w),%d0    | read the next number digit
    subq.w    #1,%d3    | decrement the read index
    cmp.b    %d4,%d0    | compare the digit with "."
    bne.s    labU00D    | if not "." go save the digit

    bra      labU00E    | else go get the next digit

labU00F:
    move.b    %d4,(%a2,%d2.w)    | save the decimal point
labU010:
    tst.w    %d2    | test the number string decimal point index
    bne.s    labU014    | if dp present skip the reset

    move.w    %d6,%d2    | make the decimal point index = the length

| copy the fractional digit characters from the number string

labU014:
    move.w    %d2,%d3    | copy the number string decimal point index
    addq.w    #1,%d3    | increment the number string index
    move.w    %sp@(fsdpi),%d4    | get the new format string decimal point index
labU018:
    addq.w    #1,%d4    | increment the new format string index
    cmp.w    %d4,%d1    | compare it with the new format string length
    bls.s    labU022    | if done the fraction digits go do integer

    move.b    (%a0,%d4.w),%d0    | get a new format string character
    cmp.b    #'%',%d0    | compare it with "%"
    beq     labU01C    | if "%" go copy a number character

    cmp.b    #'#',%d0    | compare it with "#"
    bne.s    labU018    | if not "#" go do the next new format character

labU01C:
    moveq    #'0',%d0    | default to "0" character
    cmp.w    %d3,%d6    | compare the number string index with length
    bls.s    labU020    | if there skip the character get

    move.b    (%a2,%d3.w),%d0    | get a character from the number string
    addq.w    #1,%d3    | increment the number string index
labU020:
    move.b    %d0,(%a0,%d4.w)    | save the number character to the new format
            | string
    bra      labU018    | go do the next new format character

| now copy the integer digit characters from the number string

labU022:
    moveq    #0,%d6    | clear the sign done flag
    moveq    #0,%d5    | clear the sign present flag
    subq.w    #1,%d2    | decrement the number string index
    bne.s    labU026    | if not now at sign continue

    moveq    #1,%d2    | increment the number string index
    move.b    #'0',(%a2,%d2.w)    | replace the point with a zero
labU026:
    move.w    %sp@(fsdpi),%d4    | get the new format string decimal point index
    cmp.w    %d4,%d1    | compare it with the new format string length
    bcc      labU02A    | if within the string go use the index

    move.w    %d1,%d4    | else set the index to the end of the string
labU02A:
    subq.w    #1,%d4    | decrement the new format string index
    bmi      labU03E    | if all done go test for any overflow

    move.b    (%a0,%d4.w),%d0    | else get a new format string character

    moveq    #'0',%d7    | default to "0" character
    cmp.b    #'%',%d0    | compare it with "%"
    beq     labU02B    | if "%" go copy a number character

    moveq    #' ',%d7    | default to " " character
    cmp.b    #'#',%d0    | compare it with "#"
    bne.s    labU02C    | if not "#" go try ","

labU02B:
    tst.w    %d2    | test the number string index
    bne.s    labU036    | if not at the sign go get a number character

    bra      labU03C    | else go save the default character

labU02C:
    cmp.b    #',',%d0    | compare it with ","
    bne.s    labU030    | if not "," go try the sign characters

    tst.w    %d2    | test the number string index
    bne.s    labU02E    | if not at the sign keep the ","

    cmp.b    #'%',-1(%a0,%d4.w)    | else compare the next format string character
            | with "%"
    bne.s    labU03C    | if not "%" keep the default character

labU02E:
    move.b    %d0,%d7    | else use the "," character
    bra      labU03C    | go save the character to the string

labU030:
    cmp.b    #'-',%d0    | compare it with "-"
    beq     labU034    | if "-" go do the sign character

    cmp.b    #'+',%d0    | compare it with "+"
    bne.s    labU02A    | if not "+" go do the next new format character

    cmp.b    #'-',%a2@    | compare the sign character with "-"
    beq     labU034    | if "-" do not change the sign character

    move.b    #'+',%a2@    | else make the sign character "+"
labU034:
    move.b    %d0,%d5    | set the sign present flag
    tst.w    %d2    | test the number string index
    beq     labU038    | if at the sign keep the default character

labU036:
    move.b    (%a2,%d2.w),%d7    | else get a character from the number string
    subq.w    #1,%d2    | decrement the number string index
    bra      labU03C    | go save the character

labU038:
    tst.b    %d6    | test the sign done flag
    bne.s    labU03C    | if the sign has been done go use the space
            | character

    move.b    %a2@,%d7    | else get the sign character
    move.b    %d7,%d6    | flag that the sign has been done
labU03C:
    move.b    %d7,(%a0,%d4.w)    | save the number character to the new format
            | string
    bra      labU02A    | go do the next new format character

| test for overflow conditions

labU03E:
    tst.w    %d2    | test the number string index
    bne.s    labU040    | if all the digits are not done go output
            | an overflow indication

| test for sign overflows

    tst.b    %d5    | test the sign present flag
    beq     labU04A    | if no sign present go add the string

| there was a sign in the format string

    tst.b    %d6    | test the sign done flag
    bne.s    labU04A    | if the sign is done go add the string

| the sign is not done so see if it was mandatory

    cmpi.b    #'+',%d5    | compare the sign with "+"
    beq     labU040    | if it was "+" go output an overflow
            | indication

| the sign was not mandatory but the number may have been negative

    cmp.b    #'-',%a2@    | compare the sign character with "-"
    bne.s    labU04A    | if it was not "-" go add the string

| else the sign was "-" and a sign has not been output so ..

| the number overflowed the format string so replace all the special format characters
| with the overflow character

labU040:
    moveq    #ofchr,%d5    | set the overflow character
    move.w    %d1,%d7    | copy the new format string length
    subq.w    #1,%d7    | adjust for the loop type
    move.w    %sp@(fsti),%d6    | copy the new format string last index
    subq.w    #1,%d6    | -1 gives the last character of this string
    bgt.s    labU044    | if not zero continue

    move.w    %d7,%d6    | else set the format string index to the end
labU044:
    move.b    (%a1,%d6.w),%d0    | get a character from the format string
    cmpi.b    #'#',%d0    | compare it with "#" special format character
    beq     labU046    | if "#" go use the overflow character

    cmpi.b    #'%',%d0    | compare it with "%" special format character
    beq     labU046    | if "%" go use the overflow character

    cmpi.b    #',',%d0    | compare it with "," special format character
    beq     labU046    | if "," go use the overflow character

    cmpi.b    #'+',%d0    | compare it with "+" special format character
    beq     labU046    | if "+" go use the overflow character

    cmpi.b    #'-',%d0    | compare it with "-" special format character
    beq     labU046    | if "-" go use the overflow character

    cmpi.b    #'.',%d0    | compare it with "." special format character
    bne.s    labU048    | if not "." skip the using overflow character

labU046:
    move.b    %d5,%d0    | use the overflow character
labU048:
    move.b    %d0,(%a0,%d7.w)    | save the character to the new format string
    subq.w    #1,%d6    | decrement the format string index
    dbf    %d7,labU044    | decrement the count and loop if not all done

| add the new string to the previous string

labU04A:
    lea    %a4@(6),%a0    | get the descriptor pointer for string 1
    move.l    %a4,%a3@(FAC1_m)    | save the descriptor pointer for string 2
    bsr    lab224E    | concatenate the strings

| now check for any tail on the format string

    move.w    %sp@(fsti),%d0    | get this index
    beq     labU04C    | if at start of string skip the output

    move.w    %d0,%sp@(fsli)    | save this index to the last index
    bsr    labProcFo    | now process the format string
    tst.b    %d2    | test the special characters flag
    bne.s    labU04C    | if special characters present skip the output

| else output the new string part

    bsr      labDupFmt    | duplicate the processed format string section
    move.w    %sp@(fsti),%sp@(fsli)    | copy this index to the last index

| add the new string to the previous string

    lea    %a4@(6),%a0    | get the descriptor pointer for string 1
    move.l    %a4,%a3@(FAC1_m)    | save the descriptor pointer for string 2
    bsr    lab224E    | concatenate the strings

| check for another value or end of function

labU04C:
    move.b    %a5@+,%d0    | get the next BASIC byte
    cmp.b    #')',%d0    | compare with close bracket
    bne    labU002    | if not ")" go do next value

| pop the result string off the descriptor stack

    movea.l    %a4,%a0    | copy the result string descriptor pointer
    move.l    %a3@(Sstorl),%d1    | save the bottom of string space
    bsr    lab22BA    | pop %a0@ descriptor, returns with ..
            | d0 = length, a0 = pointer
    move.l    %d1,%a3@(Sstorl)    | restore the bottom of string space
    movea.l    %a0,%a1    | copy the string result pointer
    move.w    %d0,%d1    | copy the string result length

| pop the format string off the descriptor stack

    movea.l    %sp@+,%a0    | pull the format string descriptor pointer
    bsr    lab22BA    | pop %a0@ descriptor, returns with ..
            | d0 = length, a0 = pointer

    lea    %sp@(fend),%sp    | dump the saved values

| push the result string back on the descriptor stack and return

    movea.l    %a1,%a0    | copy the result string pointer back
    bra    labrtsT    | push a string on the descriptor stack and
            | return. a0 = pointer, d1 = length


|************************************************************************************
|
| duplicate the processed format string section

            | make a string as long as the format string
labDupFmt:
    movea.l    %sp@(4+fsd),%a1    | get the format string descriptor pointer
    move.w    %a1@(4),%d7    | get the format string length
    move.w    %sp@(fsli+4),%d2    | get the format string last index
    move.w    %sp@(fsti+4),%d6    | get the format string this index
    move.w    %d6,%d1    | copy the format string this index
    sub.w    %d2,%d1    | subtract the format string last index
    BHI.s    labD002    | if > 0 skip the correction

    add.w    %d7,%d1    | else add the format string length as the
            | correction
labD002:
    bsr    lab2115    | make string space d1 bytes long
            | return a0/Sutill = pointer, others unchanged

| push the new string on the descriptor stack

    bsr    labrtsT    | push a string on the descriptor stack and
            | return. a0 = pointer, d1 = length

| copy the characters from the format string

    movea.l    %sp@(4+fsd),%a1    | get the format string descriptor pointer
    movea.l    %a1@,%a1    | get the format string pointer
    moveq    #0,%d4    | clear the new string index
labD00A:
    move.b    (%a1,%d2.w),(%a0,%d4.w)    | get a character from the format string and
            | save it to the new string
    addq.w    #1,%d4    | increment the new string index
    addq.w    #1,%d2    | increment the format string index
    cmp.w    %d2,%d7    | compare the format index with the length
    bne.s    labD00E    | if not there skip the reset

    moveq    #0,%d2    | else reset the format string index
labD00E:
    cmp.w    %d2,%d6    | compare the index with this index
    bne.s    labD00A    | if not equal go do the next character

    rts


|*************************************************************************************
|
| process the format string

labProcFo:
    movea.l    %sp@(4+fsd),%a1    | get the format string descriptor pointer
    move.w    %a1@(4),%d7    | get the format string length
    movea.l    %a1@,%a1    | get the format string pointer
    move.w    %sp@(fsli+4),%d6    | get the format string last index

    move.w    %d7,%sp@(fsdpi+4)    | set the format string decimal point index
|##    move.w    #-1,%sp@(fsdpi+4)    | set the format string decimal point index
    moveq    #0,%d5    | no decimal point
    moveq    #0,%d3    | no decimal characters
    moveq    #0,%d2    | no special characters
labP004:
    move.b    (%a1,%d6.w),%d0    | get a format string byte

    cmp.b    #',',%d0    | compare it with ","
    beq     labP01A    | if "," go do the next format string byte

    cmp.b    #'#',%d0    | compare it with "#"
    beq     labP008    | if "#" go flag special characters

    cmp.b    #'%',%d0    | compare it with "%"
    bne.s    labP00C    | if not "%" go try "+"

labP008:
    tst.l    %d5    | test the decimal point flag
    bpl.s    labP00E    | if no point skip counting decimal characters

    addq.w    #1,%d3    | else increment the decimal character count
    bra      labP01A    | go do the next character

labP00C:
    cmp.b    #'+',%d0    | compare it with "+"
    beq     labP00E    | if "+" go flag special characters

    cmp.b    #'-',%d0    | compare it with "-"
    bne.s    labP010    | if not "-" go check decimal point

labP00E:
    OR.b    %d0,%d2    | flag special characters
    bra      labP01A    | go do the next character

labP010:
    cmp.b    #'.',%d0    | compare it with "."
    bne.s    labP018    | if not "." go check next

| "." a decimal point

    tst.l    %d5    | if there is already a decimal point
    bmi      labP01A    | go do the next character

    move.w    %d6,%d0    | copy the decimal point index
    sub.w    %sp@(fsli+4),%d0    | calculate it from the scan start
    move.w    %d0,%sp@(fsdpi+4)    | save the decimal point index
    moveq    #-1,%d5    | flag decimal point
    OR.b    %d0,%d2    | flag special characters
    bra      labP01A    | go do the next character

| was not a special character

labP018:
    tst.b    %d2    | test if there have been special characters
    bne.s    labP01E    | if so exit the format string process

labP01A:
    addq.w    #1,%d6    | increment the format string index
    cmp.w    %d6,%d7    | compare it with the format string length
    BHI.s    labP004    | if length > index go get the next character

    moveq    #0,%d6    | length = index so reset the format string
            | index
labP01E:
    move.w    %d6,%sp@(fsti+4)    | save the format string this index
    move.w    %d3,%sp@(4+fsdc)    | save the format string decimal characters

    rts


|************************************************************************************
|
| perform BIN$()
| # of leading 0s is in %d1, the number is in d0

labBINS:
    cmp.b    #0x21,%d1    | max + 1
    bcc    labFCER    | exit if too big ( > or = )

    moveq    #0x1F,%d2    | bit count-1
    lea    %a3@(Binss),%a0    | point to string
    moveq    #0x30,%d4    | "0" character for addX
NextB1:
    moveq    #0,%d3    | clear byte
    lsr.l    #1,%d0    | shift bit into Xb
    addX.b    %d4,%d3    | add carry and character to zero
    move.b    %d3,(%a0,%d2.w)    | save character to string
    dbf    %d2,NextB1    | decrement and loop if not done

| this is the exit code and is also used by HEX$()

EndBHS:
    move.b    #0,%a3@(BHsend)    | null terminate the string
    tst.b    %d1    | test # of characters
    beq     NextB2    | go truncate string

    neg.l    %d1    | make -ve
    add.l    #BHsend,%d1    | effectively (end-length)
    lea    0(%a3,%d1.w),%a0    | effectively add (end-length) to pointer
    bra      BinPr    | go print string

| truncate string to remove leading "0"s

NextB2:
    move.b    %a0@,%d0    | get byte
    beq     BinPr    | if null then end of string so add 1 and go
            | print it

    cmp.b    #'0',%d0    | compare with "0"
    bne.s    GoPr    | if not "0" then go print string from here

    addq.w    #1,%a0    | else increment pointer
    bra      NextB2    | loop always

| make fixed length output string - ignore overflows!

BinPr:
    lea    %a3@(BHsend),%a1    | get string end
    cmpA.l    %a1,%a0    | are we at the string end
    bne.s    GoPr    | branch if not

    subq.w    #1,%a0    | else need at least one zero
GoPr:
    bra    lab20AE    | print double-quote-terminated string to FAC1, stack & RET


|************************************************************************************
|
| perform HEX$()
| # of leading 0s is in %d1, the number is in d0

labHEXS:
    cmp.b    #0x09,%d1    | max + 1
    bcc    labFCER    | exit if too big ( > or = )

    moveq    #0x07,%d2    | nibble count-1
    lea    %a3@(Hexss),%a0    | point to string
    moveq    #0x30,%d4    | "0" character for ABCD
NextH1:
    move.b    %d0,%d3    | copy lowest byte
    ror.l    #4,%d0    | shift nibble into 0-3
    and.b    #0x0F,%d3    | just this nibble
    move.b    %d3,%d5    | copy it
    add.b    #0xF6,%d5    | set extend bit
    ABCD    %d4,%d3    | decimal add extend and character to zero
    move.b    %d3,(%a0,%d2.w)    | save character to string
    dbf    %d2,NextH1    | decrement and loop if not done

    bra      EndBHS    | go process string


|************************************************************************************
|
| ctrl-c check routine. includes limited "life" byte save for INGET routine

VEC_CC:
    tst.b    %a3@(ccflag)    | check [CTRL-C] check flag
    bne.s    rts_022    | exit if [CTRL-C] check inhibited

    jsr    %a3@(V_INPT)    | scan input device
    bcc      labFBA0    | exit if buffer empty

    move.b    %d0,%a3@(ccbyte)    | save received byte
    move.b    #0x20,%a3@(ccnull)    | set "life" timer for bytes countdown
    bra    lab1636    | return to BASIC

labFBA0:
    tst.b    %a3@(ccnull)    | get countdown byte
    beq     rts_022    | exit if finished

    subq.b    #1,%a3@(ccnull)    | else decrement countdown
rts_022:
    rts


|************************************************************************************
|
| get byte from input device, no waiting
| returns with carry set if byte in A

INGET:
    jsr    %a3@(V_INPT)    | call scan input device
    bcs.s    labFB95    | if byte go reset timer

    move.b    %a3@(ccnull),%d0    | get countdown
    beq     rts_022    | exit if empty

    move.b    %a3@(ccbyte),%d0    | get last received byte
labFB95:
    move.b    #0x00,%a3@(ccnull)    | clear timer because we got a byte
    ori.b    #1,%ccr    | set carry, flag we got a byte
    rts


|************************************************************************************
|
| perform MAX()

labMAX:
    bsr    labEVEZ    | evaluate expression (no decrement)
    tst.b    %a3@(Dtypef)    | test data type
    bmi    labTMER    | if string do Type missmatch Error/warm start

labMAXN:
    bsr      labPHFA    | push FAC1, evaluate expression,
            | pull FAC2 & compare with FAC1
    bcc      labMAXN    | branch if no swap to do

    bsr    lab279B    | copy FAC2 to FAC1
    bra      labMAXN    | go do next


|************************************************************************************
|
| perform MIN()

labMIN:
    bsr    labEVEZ    | evaluate expression (no decrement)
    tst.b    %a3@(Dtypef)    | test data type
    bmi    labTMER    | if string do Type missmatch Error/warm start

labMINN:
    bsr      labPHFA    | push FAC1, evaluate expression,
            | pull FAC2 & compare with FAC1
    bls.s    labMINN    | branch if no swap to do

    bsr    lab279B    | copy FAC2 to FAC1
    bra      labMINN    | go do next (branch always)

| exit routine. do not bother returning to the loop code
| check for correct exit, else so syntax error

labMMEC:
    cmp.b    #')',%d0    | is it end of function?
    bne    labSNER    | if not do MAX MIN syntax error

    lea    %sp@(4),%sp    | dump return address (faster)
    bra    labIGBY    | update BASIC execute pointer (to chr past ")")
            | and return

| check for next, evaluate & return or exit
| this is the routine that does most of the work

labPHFA:
    bsr    labGBYT    | get next BASIC byte
    cmp.b    #',',%d0    | is there more ?
    bne.s    labMMEC    | if not go do end check

    move.w    %a3@(FAC1_e),%sp@-    | push exponent and sign
    move.l    %a3@(FAC1_m),%sp@-    | push mantissa

    bsr    labEVEZ    | evaluate expression (no decrement)
    tst.b    %a3@(Dtypef)    | test data type
    bmi    labTMER    | if string do Type missmatch Error/warm start


            | pop FAC2 (MAX/MIN expression so far)
    move.l    %sp@+,%a3@(FAC2_m)    | pop mantissa

    move.w    %sp@+,%d0    | pop exponent and sign
    move.w    %d0,%a3@(FAC2_e)    | save exponent and sign
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | get FAC1 sign
    eor.b    %d0,%a3@(FAC_sc)    | eor to create sign compare
    bra    lab27FA    | compare FAC1 with FAC2 & return
            | returns d0=+1 Cb=0 if FAC1 > FAC2
            | returns d0= 0 Cb=0 if FAC1 = FAC2
            | returns d0=-1 Cb=1 if FAC1 < FAC2


|************************************************************************************
|
| perform WIDTH

labWDTH:
    cmp.b    #',',%d0    | is next byte ","
    beq     labTBSZ    | if so do tab size

    bsr    labGTBY    | get byte parameter, result in d0 and Itemp
    tst.b    %d0    | test result
    beq     labNSTT    | branch if set for infinite line

    cmp.b    #0x10,%d0    | else make min width = 16d
    bcs    labFCER    | if less do function call error & exit

| this next compare ensures that we cannot exit WIDTH via an error leaving the
| tab size greater than the line length.

    cmp.b    %a3@(TabSiz),%d0    | compare with tab size
    bcc      labNSTT    | branch if >= tab size

    move.b    %d0,%a3@(TabSiz)    | else make tab size = terminal width
labNSTT:
    move.b    %d0,%a3@(TWidth)    | set the terminal width
    bsr    labGBYT    | get BASIC byte back
    beq     WExit    | exit if no following

    cmp.b    #',',%d0    | else is it ","
    bne    labSNER    | if not do syntax error

labTBSZ:
    bsr    labSGBY    | increment and get byte, result in d0 and Itemp
    tst.b    %d0    | test TAB size
    bmi    labFCER    | if >127 do function call error & exit

    cmp.b    #1,%d0    | compare with min-1
    bcs    labFCER    | if <=1 do function call error & exit

    move.b    %a3@(TWidth),%d1    | set flags for width
    beq     labSVTB    | skip check if infinite line

    cmp.b    %a3@(TWidth),%d0    | compare TAB with width
    bgt    labFCER    | branch if too big

labSVTB:
    move.b    %d0,%a3@(TabSiz)    | save TAB size

| calculate tab column limit from TAB size. The Iclim is set to the last tab
| position on a line that still has at least one whole tab width between it
| and the end of the line.

WExit:
    move.b    %a3@(TWidth),%d0    | get width
    beq     labWDLP    | branch if infinite line

    cmp.b    %a3@(TabSiz),%d0    | compare with tab size
    bcc      labWDLP    | branch if >= tab size

    move.b    %d0,%a3@(TabSiz)    | else make tab size = terminal width
labWDLP:
    sub.b    %a3@(TabSiz),%d0    | subtract tab size
    bcc      labWDLP    | loop while no borrow

    add.b    %a3@(TabSiz),%d0    | add tab size back
    add.b    %a3@(TabSiz),%d0    | add tab size back again

    neg.b    %d0    | make -ve
    add.b    %a3@(TWidth),%d0    | subtract remainder from width
    move.b    %d0,%a3@(Iclim)    | save tab column limit
rts_023:
    rts


|************************************************************************************
|
| perform SQR()

| d0 is number to find the root of
| d1 is the root result
| d2 is the remainder
| d3 is a counter
| d4 is temp

|labSQR:
|    FPUTEST                    | check FPU presence
|    beq     .labSQR_NOFPU    | and emulate if none
|    FAC1toD0                | get FAC1
|    FSQRT.s    %d0,%fp0            | calculate SQRT(FAC1)
|    fmove.s    %fp0,%d0            | copy result to D0
|    D0toFAC1                | and save in FAC1
|    rts

labSQR:
    FPUTEST                             | check for FPU
    beq     .labSQR_NOFPU               | emulate if no FPU
    cmp.w   #0xA000,%a3@(FAC1_e)        | check if FAC1 is integer
    beq     labSQRF1Int                 | FAC1 is integer
    FAC1toD0                            | fetch FAC1 as sfloat
    fsqrt.s  %d0,%fp0                   | calculate SQR(FAC1) as sfloat
labSQRend:
    fmove.s %fp0,%d0                    | get result from FPU
    D0toFAC1                            | save result in FAC1
    rts
labSQRF1Int:
    fsqrt.l  %a3@(FAC1_m),%fp0          | calculate SQR(FAC1) as integer
    bra     labSQRend

.labSQR_NOFPU:
    tst.b    %a3@(FAC1_s)    | test FAC1 sign
    bmi    labFCER    | if -ve do function call error

    tst.b    %a3@(FAC1_e)    | test exponent
    beq     rts_023    | exit if zero

    movem.l    %d1-%d4,%sp@-    | save registers
    move.l    %a3@(FAC1_m),%d0    | copy FAC1
    moveq    #0,%d2    | clear remainder
    move.l    %d2,%d1    | clear root

    moveq    #0x1F,%d3    | 0x1F for dbf, 64 pairs of bits to
            | do for a 32 bit result
    btst    #0,%a3@(FAC1_e)    | test exponent odd/even
    bne.s    labSQE2    | if odd only 1 shift first time

labSQE1:
    add.l    %d0,%d0    | shift highest bit of number ..
    addX.l    %d2,%d2    | .. into remainder .. never overflows
    add.l    %d1,%d1    | root = root | 2 .. never overflows
labSQE2:
    add.l    %d0,%d0    | shift highest bit of number ..
    addX.l    %d2,%d2    | .. into remainder .. never overflows

    move.l    %d1,%d4    | copy root
    add.l    %d4,%d4    | 2n
    addq.l    #1,%d4    | 2n+1

    cmp.l    %d4,%d2    | compare 2n+1 to remainder
    bcs.s    labSQNS    | skip sub if remainder smaller

    sub.l    %d4,%d2    | subtract temp from remainder
    addq.l    #1,%d1    | increment root
labSQNS:
    dbf    %d3,labSQE1    | loop if not all done

    move.l    %d1,%a3@(FAC1_m)    | save result mantissa
    move.b    %a3@(FAC1_e),%d0    | get exponent (d0 is clear here)
    sub.w    #0x80,%d0    | normalise
    lsr.w    #1,%d0    | /2
    bcc      labSQNA    | skip increment if carry clear

    addq.w    #1,%d0    | add bit zero back in (allow for half shift)
labSQNA:
    add.w    #0x80,%d0    | re-bias to 0x80
    move.b    %d0,%a3@(FAC1_e)    | save it
    movem.l    %sp@+,%d1-%d4    | restore registers
    bra    lab24D5    | normalise FAC1 & return


|************************************************************************************
|
| perform VARPTR()

labVARPTR:
    move.b    %a5@+,%d0    | increment pointer
labVARCALL:
    bsr    labGVAR    | get variable address in a0
    bsr    lab1BFB    | scan for ")", else do syntax error/warm start
    move.l    %a0,%d0    | copy the variable address
    bra    labAYFC    | convert d0 to signed longword in FAC1 & return


|************************************************************************************
|
| perform RAMBASE

labRAM:
    lea    %a3@(ram_base),%a0    | get start of EhBASIC RAM
    move.l    %a0,%d0    | copy it
    bra    labAYFC    | convert d0 to signed longword in FAC1 & return


|************************************************************************************
|
| perform PI

labPI:
    move.l    #0xC90FDAa2,%a3@(FAC1_m)    | pi mantissa (32 bit)
    move.w    #0x8200,%a3@(FAC1_e)    | pi exponent and sign
    rts


|************************************************************************************
|
| perform TWOPI

labTWOPI:
    move.l    #0xC90FDAa2,%a3@(FAC1_m)    | 2pi mantissa (32 bit)
    move.w    #0x8300,%a3@(FAC1_e)    | 2pi exponent and sign
    rts


|************************************************************************************
|
| get ASCII string equivalent into FAC1 as integer32 or float

| entry is with a5 pointing to the first character of the string
| exit with a5 pointing to the first character after the string

| d0 is character
| d1 is mantissa
| d2 is partial and table mantissa
| d3 is mantissa exponent (decimal & binary)
| d4 is decimal exponent

| get FAC1 from string
| this routine now handles hex and binary values from strings
| starting with "0x" and "%" respectively

lab2887:
    movem.l    %d1-%d5,%sp@-    | save registers
    moveq    #0x00,%d1    | clear temp accumulator
    move.l    %d1,%d3    | set mantissa decimal exponent count
    move.l    %d1,%d4    | clear decimal exponent
    move.b    %d1,%a3@(FAC1_s)    | clear sign byte
    move.b    %d1,%a3@(Dtypef)    | set float data type
    move.b    %d1,%a3@(expneg)    | clear exponent sign
    bsr    labGBYT    | get first byte back
    bcs.s    lab28FE    | go get floating if 1st character numeric

    cmp.b    #'-',%d0    | or is it -ve number
    bne.s    lab289A    | branch if not

    move.b    #0xFF,%a3@(FAC1_s)    | set sign byte
    bra      lab289C    | now go scan & check for hex/bin/int

lab289A:
            | first character was not numeric or -
    cmp.b    #'+',%d0    | compare with '+'
    bne.s    lab289D    | branch if not '+' (go check for '.'/hex/binary
            | /integer)
    
lab289C:
            | was "+" or "-" to start, so get next character
    bsr    labIGBY    | increment & scan memory
    bcs.s    lab28FE    | branch if numeric character

lab289D:
    cmp.b    #'.',%d0    | else compare with '.'
    beq    lab2904    | branch if '.'

            | code here for hex/binary/integer numbers
    cmp.b    #'$',%d0    | compare with '$'
    beq    labCHEX    | branch if '$'

    cmp.b    #'%',%d0    | else compare with '%'
    beq    labCBIN    | branch if '%'

    bra    lab2Y01    | not #.0x%& so return 0

lab28FD:
    bsr    labIGBY    | get next character
    bcc      lab2902    | exit loop if not a digit

lab28FE:
    bsr    d1x10    | multiply d1 by 10 and add character
    bcc      lab28FD    | loop for more if no overflow

lab28FF:
            | overflowed mantissa, count 10s exponent
    addq.l    #1,%d3    | increment mantissa decimal exponent count
    bsr    labIGBY    | get next character
    bcs.s    lab28FF    | loop while numeric character

            | done overflow, now flush fraction or do E
    cmp.b    #'.',%d0    | else compare with '.'
    bne.s    lab2901    | branch if not '.'

lab2900:
            | flush remaining fraction digits
    bsr    labIGBY    | get next character
    bcs    lab2900    | loop while numeric character

lab2901:
            | done number, only (possible) exponent remains
    cmp.b    #'E',%d0    | else compare with 'E'
    bne.s    lab2Y01    | if not 'E' all done, go evaluate

            | process exponent
    bsr    labIGBY    | get next character
    bcs.s    lab2X04    | branch if digit

    cmp.b    #'-',%d0    | or is it -ve number
    beq     lab2X01    | branch if so

    cmp.b    #TK_MINUS,%d0    | or is it -ve number
    bne.s    lab2X02    | branch if not

lab2X01:
    move.b    #0xFF,%a3@(expneg)    | set exponent sign
    bra      lab2X03    | now go scan & check exponent

lab2X02:
    cmp.b    #'+',%d0    | or is it +ve number
    beq     lab2X03    | branch if so

    cmp.b    #TK_PLUS,%d0    | or is it +ve number
    bne    labSNER    | was not - + TK_MINUS TK_PLUS or # so do error

lab2X03:
    bsr    labIGBY    | get next character
    bcc      lab2Y01    | if not digit all done, go evaluate
lab2X04:
    MULU    #10,%d4    | multiply decimal exponent by 10
    and.l    #0xFF,%d0    | mask character
    sub.b    #'0',%d0    | convert to value
    add.l    %d0,%d4    | add to decimal exponent
    cmp.b    #48,%d4    | compare with decimal exponent limit+10
    BLE.s    lab2X03    | loop if no overflow/underflow

lab2X05:
            | exponent value has overflowed
    bsr    labIGBY    | get next character
    bcs.s    lab2X05    | loop while numeric digit

    bra      lab2Y01    | all done, go evaluate

lab2902:
    cmp.b    #'.',%d0    | else compare with '.'
    beq     lab2904    | branch if was '.'

    bra      lab2901    | branch if not '.' (go check/do 'E')

lab2903:
    subq.l    #1,%d3    | decrement mantissa decimal exponent
lab2904:
            | was dp so get fraction part
    bsr    labIGBY    | get next character
    bcc      lab2901    | exit loop if not a digit (go check/do 'E')

    bsr    d1x10    | multiply d1 by 10 and add character
    bcc      lab2903    | loop for more if no overflow

    bra      lab2900    | else go flush remaining fraction part

lab2Y01:
            | now evaluate result
    tst.b    %a3@(expneg)    | test exponent sign
    bpl.s    lab2Y02    | branch if sign positive

    neg.l    %d4    | negate decimal exponent
lab2Y02:
    add.l    %d3,%d4    | add mantissa decimal exponent
    moveq    #32,%d3    | set up max binary exponent
    tst.l    %d1    | test mantissa
    beq     labrtn0    | if mantissa=0 return 0

    bmi      lab2Y04    | branch if already mormalised

    subq.l    #1,%d3    | decrement bianry exponent for Dbmi loop
lab2Y03:
    add.l    %d1,%d1    | shift mantissa
    Dbmi    %d3,lab2Y03    | decrement & loop if not normalised

            | ensure not too big or small
lab2Y04:
    cmp.l    #38,%d4    | compare decimal exponent with max exponent
    bgt    labOFER    | if greater do overflow error and warm start

    cmp.l    #-38,%d4    | compare decimal exponent with min exponent
    blt.s    labret0    | if less just return zero

    neg.l    %d4    | negate decimal exponent to go right way
    MULS    #6,%d4    | 6 bytes per entry
    move.l    %a0,%sp@-    | save register
    lea    %pc@(labP_10),%a0    | point to table
    move.b    (%a0,%d4.w),%a3@(FAC2_e)    | copy exponent for multiply
    move.l    2(%a0,%d4.w),%a3@(FAC2_m)    | copy table mantissa
    move.l    %sp@+,%a0    | restore register

    eori.b    #0x80,%d3    | normalise input exponent
    move.l    %d1,%a3@(FAC1_m)    | save input mantissa
    move.b    %d3,%a3@(FAC1_e)    | save input exponent
    move.b    %a3@(FAC1_s),%a3@(FAC_sc)    | set sign as sign compare

    movem.l    %sp@+,%d1-%d5    | restore registers
    bra    labMULTIPLY    | go multiply input by table

labret0:
    moveq    #0,%d1    | clear mantissa
labrtn0:
    move.l    %d1,%d3    | clear exponent
    move.b    %d3,%a3@(FAC1_e)    | save exponent
    move.l    %d1,%a3@(FAC1_m)    | save mantissa
    movem.l    %sp@+,%d1-%d5    | restore registers
    rts


|************************************************************************************
|
| 0x for hex add-on

| gets here if the first character was "0x" for hex
| get hex number

labCHEX:
    move.b    #0x40,%a3@(Dtypef)    | set integer numeric data type
    moveq    #32,%d3    | set up max binary exponent
labCHXX:
    bsr    labIGBY    | increment & scan memory
    bcs.s    labISHN    | branch if numeric character

    OR.b    #0x20,%d0    | case convert, allow "A" to "F" and "a" to "f"
    sub.b    #'a',%d0    | subtract "a"
    bcs.s    labCHX3    | exit if <"a"

    cmp.b    #0x06,%d0    | compare normalised with 0x06 (max+1)
    bcc      labCHX3    | exit if >"f"

    add.b    #0x3A,%d0    | convert to nibble+"0"
labISHN:
    bsr      d1x16    | multiply d1 by 16 and add the character
    bcc      labCHXX    | loop for more if no overflow

            | overflowed mantissa, count 16s exponent
labCHX1:
    addq.l    #4,%d3    | increment mantissa exponent count
    BVS    labOFER    | do overflow error if overflowed

    bsr    labIGBY    | get next character
    bcs.s    labCHX1    | loop while numeric character

    OR.b    #0x20,%d0    | case convert, allow "A" to "F" and "a" to "f"
    sub.b    #'a',%d0    | subtract "a"
    bcs.s    labCHX3    | exit if <"a"

    cmp.b    #0x06,%d0    | compare normalised with 0x06 (max+1)
    bcs.s    labCHX1    | loop if <="f"

            | now return value
labCHX3:
    tst.l    %d1    | test mantissa
    beq     labrtn0    | if mantissa=0 return 0

    bmi      labexxf    | branch if already mormalised

    subq.l    #1,%d3    | decrement bianry exponent for Dbmi loop
labCHX2:
    add.l    %d1,%d1    | shift mantissa
    Dbmi    %d3,labCHX2    | decrement & loop if not normalised

labexxf:
    eori.b    #0x80,%d3    | normalise exponent
    move.b    %d3,%a3@(FAC1_e)    | save exponent
    move.l    %d1,%a3@(FAC1_m)    | save mantissa
    movem.l    %sp@+,%d1-%d5    | restore registers
rts_024:
    rts


|************************************************************************************
|
| % for binary add-on

| gets here if the first character was "%" for binary
| get binary number

labCBIN:
    move.b    #0x40,%a3@(Dtypef)    | set integer numeric data type
    moveq    #32,%d3    | set up max binary exponent
labCBXN:
    bsr    labIGBY    | increment & scan memory
    bcc      labCHX3    | if not numeric character go return value

    cmp.b    #'2',%d0    | compare with "2" (max+1)
    bcc      labCHX3    | if >="2" go return value

    move.l    %d1,%d2    | copy value
    bsr      d1x02    | multiply d1 by 2 and add character
    bcc      labCBXN    | loop for more if no overflow

            | overflowed mantissa, count 2s exponent
labCBX1:
    addq.l    #1,%d3    | increment mantissa exponent count
    BVS    labOFER    | do overflow error if overflowed

    bsr    labIGBY    | get next character
    bcc      labCHX3    | if not numeric character go return value

    cmp.b    #'2',%d0    | compare with "2" (max+1)
    bcs.s    labCBX1    | loop if <"2"

    bra      labCHX3    | if not numeric character go return value

| half way decent times 16 and times 2 with overflow checks

d1x16:
    move.l    %d1,%d2    | copy value
    add.l    %d2,%d2    | times two
    bcs.s    rts_024    | return if overflow

    add.l    %d2,%d2    | times four
    bcs.s    rts_024    | return if overflow

    add.l    %d2,%d2    | times eight
    bcs.s    rts_024    | return if overflow

d1x02:
    add.l    %d2,%d2    | times sixteen (ten/two)
    bcs.s    rts_024    | return if overflow

| now add in new digit

    and.l    #0xFF,%d0    | mask character
    sub.b    #'0',%d0    | convert to value
    add.l    %d0,%d2    | add to result
    bcs.s    rts_024    | return if overflow, it should never ever do
            | this

    move.l    %d2,%d1    | copy result
    rts

| half way decent times 10 with overflow checks

d1x10:
    move.l    %d1,%d2    | copy value
    add.l    %d2,%d2    | times two
    bcs.s    rts_025    | return if overflow

    add.l    %d2,%d2    | times four
    bcs.s    rts_025    | return if overflow

    add.l    %d1,%d2    | times five
    bcc      d1x02    | do times two and add in new digit if ok

rts_025:
    rts


|************************************************************************************
|
| token values needed for BASIC

    .equ TK_END,0x80    | 0x80
    .equ TK_FOR,TK_END+1    | 0x81
    .equ TK_Next,TK_FOR+1    | 0x82
    .equ TK_DATA,TK_Next+1    | 0x83
    .equ TK_INPUT,TK_DATA+1    | 0x84
    .equ TK_DIM,TK_INPUT+1    | 0x85
    .equ TK_READ,TK_DIM+1    | 0x86
    .equ TK_LET,TK_READ+1    | 0x87
    .equ TK_DEC,TK_LET+1    | 0x88
    .equ TK_GOTO,TK_DEC+1    | 0x89
    .equ TK_RUN,TK_GOTO+1    | 0x8A
    .equ TK_IF,TK_RUN+1    | 0x8B
    .equ TK_RESTORE,TK_IF+1    | 0x8C
    .equ TK_GOSUB,TK_RESTORE+1    | 0x8D
    .equ TK_RETURN,TK_GOSUB+1    | 0x8E
    .equ TK_REM,TK_RETURN+1    | 0x8F
    .equ TK_STOP,TK_REM+1    | 0x90
    .equ TK_ON,TK_STOP+1    | 0x91
    .equ TK_NULL,TK_ON+1    | 0x92
    .equ TK_INC,TK_NULL+1    | 0x93
    .equ TK_WAIT,TK_INC+1    | 0x94
    .equ TK_LOAD,TK_WAIT+1    | 0x95
    .equ TK_SAVE,TK_LOAD+1    | 0x96
    .equ TK_DEF,TK_SAVE+1    | 0x97
    .equ TK_POKE,TK_DEF+1    | 0x98
    .equ TK_DOKE,TK_POKE+1    | 0x99
    .equ TK_LOKE,TK_DOKE+1    | 0x9A
    .equ TK_CALL,TK_LOKE+1    | 0x9B
    .equ TK_DO,TK_CALL+1    | 0x9C
    .equ TK_LOOP,TK_DO+1    | 0x9D
    .equ TK_PRINT,TK_LOOP+1    | 0x9E
    .equ TK_CONT,TK_PRINT+1    | 0x9F
    .equ TK_LIST,TK_CONT+1    | 0xA0
    .equ TK_CLEAR,TK_LIST+1    | 0xA1
    .equ TK_NEW,TK_CLEAR+1    | 0xA2
    .equ TK_WIDTH,TK_NEW+1    | 0xA3
    .equ TK_GET,TK_WIDTH+1    | 0xA4
    .equ TK_SWAP,TK_GET+1    | 0xA5
    .equ TK_BITSET,TK_SWAP+1    | 0xA6
    .equ TK_BITCLR,TK_BITSET+1    | 0xA7
    .equ TK_TAB,TK_BITCLR+1    | 0xA8
    .equ TK_ELSE,TK_TAB+1    | 0xA9
    .equ TK_TO,TK_ELSE+1    | 0xAA
    .equ TK_FN,TK_TO+1    | 0xAB
    .equ TK_SPC,TK_FN+1    | 0xAC
    .equ TK_THEN,TK_SPC+1    | 0xAD
    .equ TK_NOT,TK_THEN+1    | 0xAE
    .equ TK_STEP,TK_NOT+1    | 0xAF
    .equ TK_UNTIL,TK_STEP+1    | 0xB0
    .equ TK_WHILE,TK_UNTIL+1    | 0xB1
    .equ TK_PLUS,TK_WHILE+1    | 0xB2
    .equ TK_MINUS,TK_PLUS+1    | 0xB3
    .equ TK_MULT,TK_MINUS+1    | 0xB4
    .equ TK_DIV,TK_MULT+1    | 0xB5
    .equ TK_POWER,TK_DIV+1    | 0xB6
    .equ TK_AND,TK_POWER+1    | 0xB7
    .equ TK_EOR,TK_AND+1    | 0xB8
    .equ TK_OR,TK_EOR+1    | 0xB9
    .equ TK_RSHIFT,TK_OR+1    | 0xBA
    .equ TK_LSHIFT,TK_RSHIFT+1    | 0xBB
    .equ TK_GT,TK_LSHIFT+1    | 0xBC
    .equ TK_EQUAL,TK_GT+1    | 0xBD
    .equ TK_LT,TK_EQUAL+1    | 0xBE
    .equ TK_SGN,TK_LT+1    | 0xBF
    .equ TK_INT,TK_SGN+1    | 0xC0
    .equ TK_ABS,TK_INT+1    | 0xC1
    .equ TK_USR,TK_ABS+1    | 0xC2
    .equ TK_FRE,TK_USR+1    | 0xC3
    .equ TK_POS,TK_FRE+1    | 0xC4
    .equ TK_SQR,TK_POS+1    | 0xC5
    .equ TK_RND,TK_SQR+1    | 0xC6
    .equ TK_LOG,TK_RND+1    | 0xC7
    .equ TK_EXP,TK_LOG+1    | 0xC8
    .equ TK_COS,TK_EXP+1    | 0xC9
    .equ TK_SIN,TK_COS+1    | 0xCA
    .equ TK_TAN,TK_SIN+1    | 0xCB
    .equ TK_ATN,TK_TAN+1    | 0xCC
    .equ TK_PEEK,TK_ATN+1    | 0xCD
    .equ TK_DEEK,TK_PEEK+1    | 0xCE
    .equ TK_LEEK,TK_DEEK+1    | 0xCF
    .equ TK_LEN,TK_LEEK+1    | 0xD0
    .equ TK_STRS,TK_LEN+1    | 0xD1
    .equ TK_VAL,TK_STRS+1    | 0xD2
    .equ TK_ASC,TK_VAL+1    | 0xD3
    .equ TK_UCASES,TK_ASC+1    | 0xD4
    .equ TK_LCASES,TK_UCASES+1    | 0xD5
    .equ TK_CHRS,TK_LCASES+1    | 0xD6
    .equ TK_HEXS,TK_CHRS+1    | 0xD7
    .equ TK_BINS,TK_HEXS+1    | 0xD8
    .equ TK_BITTST,TK_BINS+1    | 0xD9
    .equ TK_MAX,TK_BITTST+1    | 0xDA
    .equ TK_MIN,TK_MAX+1    | 0xDB
    .equ TK_RAM,TK_MIN+1    | 0xDC
    .equ TK_PI,TK_RAM+1    | 0xDD
    .equ TK_TWOPI,TK_PI+1    | 0xDE
    .equ TK_VPTR,TK_TWOPI+1    | 0xDF
    .equ TK_Sadd,TK_VPTR+1    | 0xE0
    .equ TK_LEFTS,TK_Sadd+1    | 0xE1
    .equ TK_RIGHTS,TK_LEFTS+1    | 0xE2
    .equ TK_MIDS,TK_RIGHTS+1    | 0xE3
    .equ TK_USINGS,TK_MIDS+1    | 0xE4


|************************************************************************************
|
| binary to unsigned decimal table

Bin2dec:
    dc.l    0x3B9ACA00    | 1000000000
    dc.l    0x05F5E100    | 100000000
    dc.l    0x00989680    | 10000000
    dc.l    0x000F4240    | 1000000
    dc.l    0x000186A0    | 100000
    dc.l    0x00002710    | 10000
    dc.l    0x000003E8    | 1000
    dc.l    0x00000064    | 100
    dc.l    0x0000000A    | 10
    dc.l    0x00000000    | 0 end marker

labRSED:
    dc.l    0x332E3232    | 858665522

| string to value exponent table

    dc.w    255<<8    | 10**38
    dc.l    0x96769951
    dc.w    251<<8    | 10**37
    dc.l    0xF0BDC21B
    dc.w    248<<8    | 10**36
    dc.l    0xC097CE7C
    dc.w    245<<8    | 10**35
    dc.l    0x9A130B96
    dc.w    241<<8    | 10**34
    dc.l    0xF684DF57
    dc.w    238<<8    | 10**33
    dc.l    0xC5371912
    dc.w    235<<8    | 10**32
    dc.l    0x9DC5ADA8
    dc.w    231<<8    | 10**31
    dc.l    0xFC6F7C40
    dc.w    228<<8    | 10**30
    dc.l    0xC9F2C9CD
    dc.w    225<<8    | 10**29
    dc.l    0xA18F07D7
    dc.w    222<<8    | 10**28
    dc.l    0x813F3979
    dc.w    218<<8    | 10**27
    dc.l    0xCECB8F28
    dc.w    215<<8    | 10**26
    dc.l    0xA56FA5BA
    dc.w    212<<8    | 10**25
    dc.l    0x84595161
    dc.w    208<<8    | 10**24
    dc.l    0xD3C21BCF
    dc.w    205<<8    | 10**23
    dc.l    0xA968163F
    dc.w    202<<8    | 10**22
    dc.l    0x87867832
    dc.w    198<<8    | 10**21
    dc.l    0xD8D726B7
    dc.w    195<<8    | 10**20
    dc.l    0xAD78EBC6
    dc.w    192<<8    | 10**19
    dc.l    0x8AC72305
    dc.w    188<<8    | 10**18
    dc.l    0xDE0B6B3A
    dc.w    185<<8    | 10**17
    dc.l    0xB1A2BC2F
    dc.w    182<<8    | 10**16
    dc.l    0x8E1BC9BF
    dc.w    178<<8    | 10**15
    dc.l    0xE35FA932
    dc.w    175<<8    | 10**14
    dc.l    0xB5E620F5
    dc.w    172<<8    | 10**13
    dc.l    0x9184E72A
    dc.w    168<<8    | 10**12
    dc.l    0xE8D4A510
    dc.w    165<<8    | 10**11
    dc.l    0xBA43B740
    dc.w    162<<8    | 10**10
    dc.l    0x9502F900
    dc.w    158<<8    | 10**9
    dc.l    0xEE6B2800
    dc.w    155<<8    | 10**8
    dc.l    0xBEBC2000
    dc.w    152<<8    | 10**7
    dc.l    0x98968000
    dc.w    148<<8    | 10**6
    dc.l    0xF4240000
    dc.w    145<<8    | 10**5
    dc.l    0xC3500000
    dc.w    142<<8    | 10**4
    dc.l    0x9C400000
    dc.w    138<<8    | 10**3
    dc.l    0xFA000000
    dc.w    135<<8    | 10**2
    dc.l    0xC8000000
    dc.w    132<<8    | 10**1
    dc.l    0xA0000000
labP_10:
    dc.w    129<<8    | 10**0
    dc.l    0x80000000
    dc.w    125<<8    | 10**-1
    dc.l    0xCCCCCCCD
    dc.w    122<<8    | 10**-2
    dc.l    0xA3D70A3D
    dc.w    119<<8    | 10**-3
    dc.l    0x83126E98
    dc.w    115<<8    | 10**-4
    dc.l    0xD1B71759
    dc.w    112<<8    | 10**-5
    dc.l    0xA7C5AC47
    dc.w    109<<8    | 10**-6
    dc.l    0x8637BD06
    dc.w    105<<8    | 10**-7
    dc.l    0xD6BF94D6
    dc.w    102<<8    | 10**-8
    dc.l    0xAbcc7712
    dc.w    99<<8    | 10**-9
    dc.l    0x89705F41
    dc.w    95<<8    | 10**-10
    dc.l    0xDBE6FECF
    dc.w    92<<8    | 10**-11
    dc.l    0xAFEBFF0C
    dc.w    89<<8    | 10**-12
    dc.l    0x8CbccC09
    dc.w    85<<8    | 10**-13
    dc.l    0xE12E1342
    dc.w    82<<8    | 10**-14
    dc.l    0xB424DC35
    dc.w    79<<8    | 10**-15
    dc.l    0x901D7CF7
    dc.w    75<<8    | 10**-16
    dc.l    0xE69594BF
    dc.w    72<<8    | 10**-17
    dc.l    0xB877AA32
    dc.w    69<<8    | 10**-18
    dc.l    0x9392EE8F
    dc.w    65<<8    | 10**-19
    dc.l    0xEC1E4A7E
    dc.w    62<<8    | 10**-20
    dc.l    0xBCE50865
    dc.w    59<<8    | 10**-21
    dc.l    0x971DA050
    dc.w    55<<8    | 10**-22
    dc.l    0xF1C90081
    dc.w    52<<8    | 10**-23
    dc.l    0xC16D9A01
    dc.w    49<<8    | 10**-24
    dc.l    0x9ABE14CD
    dc.w    45<<8    | 10**-25
    dc.l    0xF79687AE
    dc.w    42<<8    | 10**-26
    dc.l    0xC6120625
    dc.w    39<<8    | 10**-27
    dc.l    0x9E74D1B8
    dc.w    35<<8    | 10**-28
    dc.l    0xFD87B5F3
    dc.w    32<<8    | 10**-29
    dc.l    0xCAD2F7F5
    dc.w    29<<8    | 10**-30
    dc.l    0xA2425FF7
    dc.w    26<<8    | 10**-31
    dc.l    0x81CEB32C
    dc.w    22<<8    | 10**-32
    dc.l    0xCFB11EAD
    dc.w    19<<8    | 10**-33
    dc.l    0xA6274BBE
    dc.w    16<<8    | 10**-34
    dc.l    0x84EC3C98
    dc.w    12<<8    | 10**-35
    dc.l    0xD4AD2DC0
    dc.w    9<<8    | 10**-36
    dc.l    0xAA242499
    dc.w    6<<8    | 10**-37
    dc.l    0x881CEA14
    dc.w    2<<8    | 10**-38
    dc.l    0xD9C7DCED


|************************************************************************************
|
| table of constants for cordic SIN/COS/TAN calculations
| constants are un normalised fractions and are atn(2^-i)/2pi

    dc.l    0x4DBA76D4    | SIN/COS multiply constant
TAB_SNCO:
    dc.l    0x20000000    | atn(2^0)/2pi
    dc.l    0x12E4051E    | atn(2^1)/2pi
    dc.l    0x09FB385C    | atn(2^2)/2pi
    dc.l    0x051111D5    | atn(2^3)/2pi
    dc.l    0x028B0D44    | atn(2^4)/2pi
    dc.l    0x0145D7E2    | atn(2^5)/2pi
    dc.l    0x00A2F61F    | atn(2^6)/2pi
    dc.l    0x00517C56    | atn(2^7)/2pi
    dc.l    0x0028BE54    | atn(2^8)/2pi
    dc.l    0x00145F2F    | atn(2^9)/2pi
    dc.l    0x000A2F99    | atn(2^10)/2pi
    dc.l    0x000517CD    | atn(2^11)/2pi
    dc.l    0x00028BE7    | atn(2^12)/2pi
    dc.l    0x000145F4    | atn(2^13)/2pi
    dc.l    0x0000A2FA    | atn(2^14)/2pi
    dc.l    0x0000517D    | atn(2^15)/2pi
    dc.l    0x000028BF    | atn(2^16)/2pi
    dc.l    0x00001460    | atn(2^17)/2pi
    dc.l    0x00000A30    | atn(2^18)/2pi
    dc.l    0x00000518    | atn(2^19)/2pi
    dc.l    0x0000028C    | atn(2^20)/2pi
    dc.l    0x00000146    | atn(2^21)/2pi
    dc.l    0x000000A3    | atn(2^22)/2pi
    dc.l    0x00000052    | atn(2^23)/2pi
    dc.l    0x00000029    | atn(2^24)/2pi
    dc.l    0x00000015    | atn(2^25)/2pi
    dc.l    0x0000000B    | atn(2^26)/2pi
    dc.l    0x00000006    | atn(2^27)/2pi
    dc.l    0x00000003    | atn(2^28)/2pi
    dc.l    0x00000002    | atn(2^29)/2pi
    dc.l    0x00000001    | atn(2^30)/2pi
    dc.l    0x00000001    | atn(2^31)/2pi


|************************************************************************************
|
| table of constants for cordic ATN calculation
| constants are normalised to two integer bits and are atn(2^-i)

TAB_ATNC:
    dc.l    0x1DAC6705    | atn(2^-1)
    dc.l    0x0FADBAFD    | atn(2^-2)
    dc.l    0x07F56EA7    | atn(2^-3)
    dc.l    0x03FEAB77    | atn(2^-4)
    dc.l    0x01FFD55C    | atn(2^-5)
    dc.l    0x00FFFAAB    | atn(2^-6)
    dc.l    0x007FFF55    | atn(2^-7)
    dc.l    0x003FFFEB    | atn(2^-8)
    dc.l    0x001FFFFD    | atn(2^-9)
    dc.l    0x00100000    | atn(2^-10)
    dc.l    0x00080000    | atn(2^-11)
    dc.l    0x00040000    | atn(2^-12)
    dc.l    0x00020000    | atn(2^-13)
    dc.l    0x00010000    | atn(2^-14)
    dc.l    0x00008000    | atn(2^-15)
    dc.l    0x00004000    | atn(2^-16)
    dc.l    0x00002000    | atn(2^-17)
    dc.l    0x00001000    | atn(2^-18)
    dc.l    0x00000800    | atn(2^-19)
    dc.l    0x00000400    | atn(2^-20)
    dc.l    0x00000200    | atn(2^-21)
    dc.l    0x00000100    | atn(2^-22)
    dc.l    0x00000080    | atn(2^-23)
    dc.l    0x00000040    | atn(2^-24)
    dc.l    0x00000020    | atn(2^-25)
    dc.l    0x00000010    | atn(2^-26)
    dc.l    0x00000008    | atn(2^-27)
    dc.l    0x00000004    | atn(2^-28)
    dc.l    0x00000002    | atn(2^-29)
    dc.l    0x00000001    | atn(2^-30)
lab1D96:
    dc.l    0x00000000    | atn(2^-31)
    dc.l    0x00000000    | atn(2^-32)

| constants are normalised to n integer bits and are tanh(2^-i)
    .equ n,2
TAB_HTHET:
    dc.l    0x8C9F53D0>>n    | atnh(2^-1)    .549306144
    dc.l    0x4162BBE8>>n    | atnh(2^-2)    .255412812
    dc.l    0x202B1238>>n    | atnh(2^-3)
    dc.l    0x10055888>>n    | atnh(2^-4)
    dc.l    0x0800AAC0>>n    | atnh(2^-5)
    dc.l    0x04001550>>n    | atnh(2^-6)
    dc.l    0x020002A8>>n    | atnh(2^-7)
    dc.l    0x01000050>>n    | atnh(2^-8)
    dc.l    0x00800008>>n    | atnh(2^-9)
    dc.l    0x00400000>>n    | atnh(2^-10)
    dc.l    0x00200000>>n    | atnh(2^-11)
    dc.l    0x00100000>>n    | atnh(2^-12)
    dc.l    0x00080000>>n    | atnh(2^-13)
    dc.l    0x00040000>>n    | atnh(2^-14)
    dc.l    0x00020000>>n    | atnh(2^-15)
    dc.l    0x00010000>>n    | atnh(2^-16)
    dc.l    0x00008000>>n    | atnh(2^-17)
    dc.l    0x00004000>>n    | atnh(2^-18)
    dc.l    0x00002000>>n    | atnh(2^-19)
    dc.l    0x00001000>>n    | atnh(2^-20)
    dc.l    0x00000800>>n    | atnh(2^-21)
    dc.l    0x00000400>>n    | atnh(2^-22)
    dc.l    0x00000200>>n    | atnh(2^-23)
    dc.l    0x00000100>>n    | atnh(2^-24)
    dc.l    0x00000080>>n    | atnh(2^-25)
    dc.l    0x00000040>>n    | atnh(2^-26)
    dc.l    0x00000020>>n    | atnh(2^-27)
    dc.l    0x00000010>>n    | atnh(2^-28)
    dc.l    0x00000008>>n    | atnh(2^-29)
    dc.l    0x00000004>>n    | atnh(2^-30)
    dc.l    0x00000002>>n    | atnh(2^-31)
    dc.l    0x00000001>>n    | atnh(2^-32)

    .equ KFCTSEED,0x9A8F4441>>n    | 0x26A3D110


|************************************************************************************
|
| command vector table

labCTBL:
    dc.w    labEND-labCTBL    | END
    dc.w    labFOR-labCTBL    | FOR
    dc.w    labNext-labCTBL    | Next
    dc.w    labDATA-labCTBL    | DATA
    dc.w    labINPUT-labCTBL    | INPUT
    dc.w    labDIM-labCTBL    | DIM
    dc.w    labREAD-labCTBL    | READ
    dc.w    labLET-labCTBL    | LET
    dc.w    labDEC-labCTBL    | DEC    
    dc.w    labGOTO-labCTBL    | GOTO
    dc.w    labRUN-labCTBL    | RUN
    dc.w    labIF-labCTBL    | IF
    dc.w    labRESTORE-labCTBL    | RESTORE
    dc.w    labGOSUB-labCTBL    | GOSUB
    dc.w    labRETURN-labCTBL    | RETURN
    dc.w    labREM-labCTBL    | REM
    dc.w    labSTOP-labCTBL    | STOP
    dc.w    labON-labCTBL    | ON
    dc.w    labNULL-labCTBL    | NULL
    dc.w    labINC-labCTBL    | INC    
    dc.w    labWAIT-labCTBL    | WAIT
    dc.w    labLOAD-labCTBL    | LOAD
    dc.w    labSAVE-labCTBL    | SAVE
    dc.w    labDEF-labCTBL    | DEF
    dc.w    labPOKE-labCTBL    | POKE
    dc.w    labDOKE-labCTBL    | DOKE
    dc.w    labLOKE-labCTBL    | LOKE
    dc.w    labCALL-labCTBL    | CALL
    dc.w    labDO-labCTBL    | DO    
    dc.w    labLOOP-labCTBL    | LOOP
    dc.w    labPRINT-labCTBL    | PRINT
    dc.w    labCONT-labCTBL    | CONT
    dc.w    labLIST-labCTBL    | LIST
    dc.w    labCLEAR-labCTBL    | CleaR
    dc.w    labNEW-labCTBL    | NEW
    dc.w    labWDTH-labCTBL    | WIDTH
    dc.w    labGET-labCTBL    | GET
    dc.w    labswap-labCTBL    | swap
    dc.w    labBITSET-labCTBL    | BITSET
    dc.w    labBITCLR-labCTBL    | BITCLR


|************************************************************************************
|
| function pre process routine table

labFTPP:
    dc.w    labPPFN-labFTPP     | SGN(n)    process numeric expression in ()
    dc.w    labPPFN-labFTPP     | INT(n)    process numeric expression in ()
    dc.w    labPPFN-labFTPP     | ABS(n)    process numeric expression in ()
    dc.w    labEVEZ-labFTPP     | USR(x)    process any expression
    dc.w    lab1BF7-labFTPP     | FRE(x)    process any expression in ()
    dc.w    lab1BF7-labFTPP     | POS(x)    process numeric expression in ()
    dc.w    labPPFN-labFTPP     | SQR(n)    process numeric expression in ()
    dc.w    labPPFN-labFTPP     | RND(n)    process numeric expression in ()
    dc.w    labPPFN-labFTPP     | LOG(n)    process numeric expression in ()
    dc.w    labPPFN-labFTPP     | EXP(n)    process numeric expression in ()
    dc.w    labPPFN-labFTPP     | COS(n)    process numeric expression in ()
    dc.w    labPPFN-labFTPP     | SIN(n)    process numeric expression in ()
    dc.w    labPPFN-labFTPP     | TAN(n)    process numeric expression in ()
    dc.w    labPPFN-labFTPP     | ATN(n)    process numeric expression in ()
    dc.w    labPPFN-labFTPP     | PEEK(n)   process numeric expression in ()
    dc.w    labPPFN-labFTPP     | DEEK(n)   process numeric expression in ()
    dc.w    labPPFN-labFTPP     | LEEK(n)   process numeric expression in ()
    dc.w    labPPFS-labFTPP     | LEN($)    process string expression in ()
    dc.w    labPPFN-labFTPP     | STR$(n)  process numeric expression in ()
    dc.w    labPPFS-labFTPP     | VAL($)    process string expression in ()
    dc.w    labPPFS-labFTPP     | ASC($)    process string expression in ()
    dc.w    labPPFS-labFTPP     | UCASE$($) process string expression in ()
    dc.w    labPPFS-labFTPP     | LCASE$($) process string expression in ()
    dc.w    labPPFN-labFTPP     | CHR$(n)   process numeric expression in ()
    dc.w    labBHSS-labFTPP     | HEX$()    bin/hex pre process
    dc.w    labBHSS-labFTPP     | BIN$()    bin/hex pre process
    dc.w    0x0000              | BITTST()  none
    dc.w    0x0000              | MAX()     none
    dc.w    0x0000              | MIN()     none
    dc.w    labPPBI-labFTPP     | RAMBASE   advance pointer
    dc.w    labPPBI-labFTPP     | PI        advance pointer
    dc.w    labPPBI-labFTPP     | TWOPI     advance pointer
    dc.w    0x0000              | VARPTR()  none
    dc.w    0x0000              | Sadd()    none
    dc.w    labLRMS-labFTPP     | LEFT$()   process string expression
    dc.w    labLRMS-labFTPP     | RIGHT$()  process string expression
    dc.w    labLRMS-labFTPP     | MID$()    process string expression
    dc.w    labEVEZ-labFTPP     | USING$(x) process any expression


|************************************************************************************
|
| action addresses for functions

labFTBL:
    dc.w    labSGN-labFTBL    | SGN()
    dc.w    labINT-labFTBL    | INT()
    dc.w    labABS-labFTBL    | ABS()
    dc.w    labUSR-labFTBL    | USR()
    dc.w    labFRE-labFTBL    | FRE()
    dc.w    labPOS-labFTBL    | POS()
    dc.w    labSQR-labFTBL    | SQR()
    dc.w    labRND-labFTBL    | RND()
    dc.w    labLOG-labFTBL    | LOG()
    dc.w    labEXP-labFTBL    | EXP()
    dc.w    labCOS-labFTBL    | COS()
    dc.w    labSIN-labFTBL    | SIN()
    dc.w    labTAN-labFTBL    | TAN()
    dc.w    labATN-labFTBL    | ATN()
    dc.w    labPEEK-labFTBL    | PEEK()
    dc.w    labDEEK-labFTBL    | DEEK()
    dc.w    labLEEK-labFTBL    | LEEK()
    dc.w    labLENS-labFTBL    | LEN()
    dc.w    labSTRS-labFTBL    | STR$()
    dc.w    labVAL-labFTBL    | VAL()
    dc.w    labASC-labFTBL    | ASC()
    dc.w    labUCASE-labFTBL    | UCASE0x()
    dc.w    labLCASE-labFTBL    | LCASE0x()
    dc.w    labCHRS-labFTBL    | CHR$()
    dc.w    labHEXS-labFTBL    | HEX$()
    dc.w    labBINS-labFTBL    | BIN$()
    dc.w    labBTST-labFTBL    | BITTST()
    dc.w    labMAX-labFTBL    | MAX()
    dc.w    labMIN-labFTBL    | MIN()
    dc.w    labRAM-labFTBL    | RAMBASE
    dc.w    labPI-labFTBL    | PI
    dc.w    labTWOPI-labFTBL    | TWOPI
    dc.w    labVARPTR-labFTBL    | VARPTR()
    dc.w    labSADD-labFTBL    | Sadd()
    dc.w    labLEFT-labFTBL    | LEFT$()
    dc.w    labRIGHT-labFTBL    | RIGHT$()
    dc.w    labMIDS-labFTBL    | MID$()
    dc.w    labUSINGS-labFTBL    | USING$()


|************************************************************************************
|
| hierarchy and action addresses for operator

labOPPT:
    dc.w    0x0079    | +
    dc.w    labADD-labOPPT
    dc.w    0x0079    | -
    dc.w    labSUBTRACT-labOPPT
    dc.w    0x007B    | |
    dc.w    labMULTIPLY-labOPPT
    dc.w    0x007B    | /
    dc.w    labDIVIDE-labOPPT
    dc.w    0x007F    | ^
    dc.w    labPOWER-labOPPT
    dc.w    0x0050    | and
    dc.w    labAND-labOPPT
    dc.w    0x0046    | eor
    dc.w    labEOR-labOPPT
    dc.w    0x0046    | OR
    dc.w    labOR-labOPPT
    dc.w    0x0056    | >>
    dc.w    labRSHIFT-labOPPT
    dc.w    0x0056    | <<
    dc.w    labLSHIFT-labOPPT
    dc.w    0x007D    | >
    dc.w    labGTHAN-labOPPT    | used to evaluate -n
    dc.w    0x005A    | =
    dc.w    labEQUAL-labOPPT    | used to evaluate NOT
    dc.w    0x0064    | <
    dc.w    labLTHAN-labOPPT


|************************************************************************************
|
| misc constants

| This table is used in converting numbers to ASCII.
| first four entries for expansion to 9.25 digits

lab2A9A:
    dc.l    0xFFF0BDC0    | -1000000
    dc.l    0x000186A0    | 100000
    dc.l    0xFFFFD8F0    | -10000
    dc.l    0x000003E8    | 1000
    dc.l    0xFFFFFF9C    | -100
    dc.l    0x0000000A    | 10
    dc.l    0xFFFFFFFF    | -1
lab2A9B:


|************************************************************************************
|
| new keyword tables

| offsets to keyword tables

TAB_CHRT:
    dc.w    TAB_STAR-TAB_STAR    | "*"    0x2A
    dc.w    TAB_PLUS-TAB_STAR    | "+"    0x2B
    dc.w    -1    | "," 0x2C no keywords
    dc.w    TAB_MNUS-TAB_STAR    | "-"    0x2D
    dc.w    -1    | "." 0x2E no keywords
    dc.w    TAB_SLAS-TAB_STAR    | "/"    0x2F
    dc.w    -1    | "0" 0x30 no keywords
    dc.w    -1    | "1" 0x31 no keywords
    dc.w    -1    | "2" 0x32 no keywords
    dc.w    -1    | "3" 0x33 no keywords
    dc.w    -1    | "4" 0x34 no keywords
    dc.w    -1    | "5" 0x35 no keywords
    dc.w    -1    | "6" 0x36 no keywords
    dc.w    -1    | "7" 0x37 no keywords
    dc.w    -1    | "8" 0x38 no keywords
    dc.w    -1    | "9" 0x39 no keywords
    dc.w    -1    | "|" 0x3A no keywords
    dc.w    -1    | ":" 0x3B no keywords
    dc.w    TAB_LESS-TAB_STAR    | "<"    0x3C
    dc.w    TAB_EQUL-TAB_STAR    | "="    0x3D
    dc.w    TAB_MORE-TAB_STAR    | ">"    0x3E
    dc.w    TAB_QEST-TAB_STAR    | "?"    0x3F
    dc.w    -1    | "@" 0x40 no keywords
    dc.w    TAB_ASCA-TAB_STAR    | "A"    0x41
    dc.w    TAB_ASCB-TAB_STAR    | "B"    0x42
    dc.w    TAB_ASCC-TAB_STAR    | "C"    0x43
    dc.w    TAB_ASCD-TAB_STAR    | "D"    0x44
    dc.w    TAB_ASCE-TAB_STAR    | "E"    0x45
    dc.w    TAB_ASCF-TAB_STAR    | "F"    0x46
    dc.w    TAB_ASCG-TAB_STAR    | "G"    0x47
    dc.w    TAB_ASCH-TAB_STAR    | "H"    0x48
    dc.w    TAB_ASCI-TAB_STAR    | "I"    0x49
    dc.w    -1    | "J" 0x4A no keywords
    dc.w    -1    | "K" 0x4B no keywords
    dc.w    TAB_ASCL-TAB_STAR    | "L"    0x4C
    dc.w    TAB_ASCM-TAB_STAR    | "M"    0x4D
    dc.w    TAB_ASCN-TAB_STAR    | "N"    0x4E
    dc.w    TAB_ASCO-TAB_STAR    | "O"    0x4F
    dc.w    TAB_ASCP-TAB_STAR    | "P"    0x50
    dc.w    -1    | "Q" 0x51 no keywords
    dc.w    TAB_ASCR-TAB_STAR    | "R"    0x52
    dc.w    TAB_ASCS-TAB_STAR    | "S"    0x53
    dc.w    TAB_ASCT-TAB_STAR    | "T"    0x54
    dc.w    TAB_ASCU-TAB_STAR    | "U"    0x55
    dc.w    TAB_ASCV-TAB_STAR    | "V"    0x56
    dc.w    TAB_ASCW-TAB_STAR    | "W"    0x57
    dc.w    -1    | "X" 0x58 no keywords
    dc.w    -1    | "Y" 0x59 no keywords
    dc.w    -1    | "Z" 0x5A no keywords
    dc.w    -1    | "[" 0x5B no keywords
    dc.w    -1    | "\\" 0x5C no keywords
    dc.w    -1    | "]" 0x5D no keywords
    dc.w    TAB_POWR-TAB_STAR    | "^"    0x5E


|************************************************************************************
|
| Table of Basic keywords for LIST command
| [byte]first character,[byte]remaining length -1
| [word]offset from table start

labKEYT:
    dc.b    'E',1
    dc.w    KEY_END-TAB_STAR    | END
    dc.b    'F',1
    dc.w    KEY_FOR-TAB_STAR    | FOR
    dc.b    'N',2
    dc.w    KEY_Next-TAB_STAR    | Next
    dc.b    'D',2
    dc.w    KEY_DATA-TAB_STAR    | DATA
    dc.b    'I',3
    dc.w    KEY_INPUT-TAB_STAR    | INPUT
    dc.b    'D',1
    dc.w    KEY_DIM-TAB_STAR    | DIM
    dc.b    'R',2
    dc.w    KEY_READ-TAB_STAR    | READ
    dc.b    'L',1
    dc.w    KEY_LET-TAB_STAR    | LET
    dc.b    'D',1
    dc.w    KEY_DEC-TAB_STAR    | DEC
    dc.b    'G',2
    dc.w    KEY_GOTO-TAB_STAR    | GOTO
    dc.b    'R',1
    dc.w    KEY_RUN-TAB_STAR    | RUN
    dc.b    'I',0
    dc.w    KEY_IF-TAB_STAR    | IF
    dc.b    'R',5
    dc.w    KEY_RESTORE-TAB_STAR    | RESTORE
    dc.b    'G',3
    dc.w    KEY_GOSUB-TAB_STAR    | GOSUB
    dc.b    'R',4
    dc.w    KEY_RETURN-TAB_STAR    | RETURN
    dc.b    'R',1
    dc.w    KEY_REM-TAB_STAR    | REM
    dc.b    'S',2
    dc.w    KEY_STOP-TAB_STAR    | STOP
    dc.b    'O',0
    dc.w    KEY_ON-TAB_STAR    | ON
    dc.b    'N',2
    dc.w    KEY_NULL-TAB_STAR    | NULL
    dc.b    'I',1
    dc.w    KEY_INC-TAB_STAR    | INC
    dc.b    'W',2
    dc.w    KEY_WAIT-TAB_STAR    | WAIT
    dc.b    'L',2
    dc.w    KEY_LOAD-TAB_STAR    | LOAD
    dc.b    'S',2
    dc.w    KEY_SAVE-TAB_STAR    | SAVE
    dc.b    'D',1
    dc.w    KEY_DEF-TAB_STAR    | DEF
    dc.b    'P',2
    dc.w    KEY_POKE-TAB_STAR    | POKE
    dc.b    'D',2
    dc.w    KEY_DOKE-TAB_STAR    | DOKE
    dc.b    'L',2
    dc.w    KEY_LOKE-TAB_STAR    | LOKE
    dc.b    'C',2
    dc.w    KEY_CALL-TAB_STAR    | CALL
    dc.b    'D',0
    dc.w    KEY_DO-TAB_STAR    | DO
    dc.b    'L',2
    dc.w    KEY_LOOP-TAB_STAR    | LOOP
    dc.b    'P',3
    dc.w    KEY_PRINT-TAB_STAR    | PRINT
    dc.b    'C',2
    dc.w    KEY_CONT-TAB_STAR    | CONT
    dc.b    'L',2
    dc.w    KEY_LIST-TAB_STAR    | LIST
    dc.b    'C',3
    dc.w    KEY_CLEAR-TAB_STAR    | CLEAR
    dc.b    'N',1
    dc.w    KEY_NEW-TAB_STAR    | NEW
    dc.b    'W',3
    dc.w    KEY_WIDTH-TAB_STAR    | WIDTH
    dc.b    'G',1
    dc.w    KEY_GET-TAB_STAR    | GET
    dc.b    'S',2
    dc.w    KEY_SWAP-TAB_STAR    | swap
    dc.b    'B',4
    dc.w    KEY_BITSET-TAB_STAR    | BITSET
    dc.b    'B',4
    dc.w    KEY_BITCLR-TAB_STAR    | BITCLR
    dc.b    'T',2
    dc.w    KEY_TAB-TAB_STAR    | TAB(
    dc.b    'E',2
    dc.w    KEY_ELSE-TAB_STAR    | ELSE
    dc.b    'T',0
    dc.w    KEY_TO-TAB_STAR    | TO
    dc.b    'F',0
    dc.w    KEY_FN-TAB_STAR    | FN
    dc.b    'S',2
    dc.w    KEY_SPC-TAB_STAR    | SPC(
    dc.b    'T',2
    dc.w    KEY_THEN-TAB_STAR    | THEN
    dc.b    'N',1
    dc.w    KEY_NOT-TAB_STAR    | NOT
    dc.b    'S',2
    dc.w    KEY_STEP-TAB_STAR    | STEP
    dc.b    'U',3
    dc.w    KEY_UNTIL-TAB_STAR    | UNTIL
    dc.b    'W',3
    dc.w    KEY_WHILE-TAB_STAR    | WHILE

    dc.b    '+',-1
    dc.w    KEY_PLUS-TAB_STAR    | +
    dc.b    '-',-1
    dc.w    KEY_MINUS-TAB_STAR    | -
    dc.b    '*',-1
    dc.w    KEY_MULT-TAB_STAR    | |
    dc.b    '/',-1
    dc.w    KEY_DIV-TAB_STAR    | /
    dc.b    '^',-1
    dc.w    KEY_POWER-TAB_STAR    | ^
    dc.b    'A',1
    dc.w    KEY_and-TAB_STAR    | and
    dc.b    'E',1
    dc.w    KEY_EOR-TAB_STAR    | eor
    dc.b    'O',0
    dc.w    KEY_OR-TAB_STAR    | OR
    dc.b    '>',0
    dc.w    KEY_RSHIFT-TAB_STAR    | >>
    dc.b    '<',0
    dc.w    KEY_LSHIFT-TAB_STAR    | <<
    dc.b    '>',-1
    dc.w    KEY_GT-TAB_STAR    | >
    dc.b    '=',-1
    dc.w    KEY_EQUAL-TAB_STAR    | =
    dc.b    '<',-1
    dc.w    KEY_LT-TAB_STAR    | <

    dc.b    'S',2
    dc.w    KEY_SGN-TAB_STAR    | SGN(
    dc.b    'I',2
    dc.w    KEY_INT-TAB_STAR    | INT(
    dc.b    'A',2
    dc.w    KEY_ABS-TAB_STAR    | ABS(
    dc.b    'U',2
    dc.w    KEY_USR-TAB_STAR    | USR(
    dc.b    'F',2
    dc.w    KEY_FRE-TAB_STAR    | FRE(
    dc.b    'P',2
    dc.w    KEY_POS-TAB_STAR    | POS(
    dc.b    'S',2
    dc.w    KEY_SQR-TAB_STAR    | SQR(
    dc.b    'R',2
    dc.w    KEY_RND-TAB_STAR    | RND(
    dc.b    'L',2
    dc.w    KEY_LOG-TAB_STAR    | LOG(
    dc.b    'E',2
    dc.w    KEY_EXP-TAB_STAR    | EXP(
    dc.b    'C',2
    dc.w    KEY_COS-TAB_STAR    | COS(
    dc.b    'S',2
    dc.w    KEY_SIN-TAB_STAR    | SIN(
    dc.b    'T',2
    dc.w    KEY_TAN-TAB_STAR    | TAN(
    dc.b    'A',2
    dc.w    KEY_ATN-TAB_STAR    | ATN(
    dc.b    'P',3
    dc.w    KEY_PEEK-TAB_STAR    | PEEK(
    dc.b    'D',3
    dc.w    KEY_DEEK-TAB_STAR    | DEEK(
    dc.b    'L',3
    dc.w    KEY_LEEK-TAB_STAR    | LEEK(
    dc.b    'L',2
    dc.w    KEY_LEN-TAB_STAR    | LEN(
    dc.b    'S',3
    dc.w    KEY_STRS-TAB_STAR    | STR$(
    dc.b    'V',2
    dc.w    KEY_VAL-TAB_STAR    | VAL(
    dc.b    'A',2
    dc.w    KEY_ASC-TAB_STAR    | ASC(
    dc.b    'U',5
    dc.w    KEY_UCASES-TAB_STAR    | UCASE0x(
    dc.b    'L',5
    dc.w    KEY_LCASES-TAB_STAR    | LCASE0x(
    dc.b    'C',3
    dc.w    KEY_CHRS-TAB_STAR    | CHR$(
    dc.b    'H',3
    dc.w    KEY_HEXS-TAB_STAR    | HEX$(
    dc.b    'B',3
    dc.w    KEY_BINS-TAB_STAR    | BIN$(
    dc.b    'B',5
    dc.w    KEY_BITTST-TAB_STAR    | BITTST(
    dc.b    'M',2
    dc.w    KEY_MAX-TAB_STAR    | MAX(
    dc.b    'M',2
    dc.w    KEY_MIN-TAB_STAR    | MIN(
    dc.b    'R',5
    dc.w    KEY_RAM-TAB_STAR    | RAMBASE
    dc.b    'P',0
    dc.w    KEY_PI-TAB_STAR    | PI
    dc.b    'T',3
    dc.w    KEY_TWOPI-TAB_STAR    | TWOPI
    dc.b    'V',5
    dc.w    KEY_VPTR-TAB_STAR    | VARPTR(
    dc.b    'S',3
    dc.w    KEY_SADD-TAB_STAR    | Sadd(
    dc.b    'L',4
    dc.w    KEY_LEFTS-TAB_STAR    | LEFT$(
    dc.b    'R',5
    dc.w    KEY_RIGHTS-TAB_STAR    | RIGHT$(
    dc.b    'M',3
    dc.w    KEY_MIDS-TAB_STAR    | MID$(
    dc.b    'U',5
    dc.w    KEY_USINGS-TAB_STAR    | USING$(


|************************************************************************************
|
| BASIC error messages

labBAER:
    dc.w    labNF-labBAER    | 0x00 Next without FOR
    dc.w    labSN-labBAER    | 0x02 syntax
    dc.w    labRG-labBAER    | 0x04 RETURN without GOSUB
    dc.w    labOD-labBAER    | 0x06 out of data
    dc.w    labFC-labBAER    | 0x08 function call
    dc.w    labOV-labBAER    | 0x0A overflow
    dc.w    labOM-labBAER    | 0x0C out of memory
    dc.w    labUS-labBAER    | 0x0E undefined statement
    dc.w    labBS-labBAER    | 0x10 array bounds
    dc.w    labDD-labBAER    | 0x12 double dimension array
    dc.w    labD0-labBAER    | 0x14 divide by 0
    dc.w    labID-labBAER    | 0x16 illegal direct
    dc.w    labTM-labBAER    | 0x18 type mismatch
    dc.w    labLS-labBAER    | 0x1A long string
    dc.w    labST-labBAER    | 0x1C string too complex
    dc.w    labCN-labBAER    | 0x1E continue error
    dc.w    labUF-labBAER    | 0x20 undefined function
    dc.w    labLD-labBAER    | 0x22 LOOP without DO
    dc.w    labUV-labBAER    | 0x24 undefined variable
    dc.w    labUA-labBAER    | 0x26 undimensioned array
    dc.w    labWD-labBAER    | 0x28 wrong dimensions
    dc.w    labAD-labBAER    | 0x2A address
    dc.w    labFO-labBAER    | 0x2C format
    dc.w    labNI-labBAER    | 0x2E not implemented

labNF:    .ascii "Next without FOR\0"
labSN:    .ascii "Syntax\0"
labRG:    .ascii "RETURN without GOSUB\0"
labOD:    .ascii "Out of DATA\0"
labFC:    .ascii "Function call\0"
labOV:    .ascii "Overflow\0"
labOM:    .ascii "Out of memory\0"
labUS:    .ascii "Undefined statement\0"
labBS:    .ascii "Array bounds\0"
labDD:    .ascii "Double dimension\0"
labD0:    .ascii "Divide by zero\0"
labID:    .ascii "Illegal direct\0"
labTM:    .ascii "Type mismatch\0"
labLS:    .ascii "String too long\0"
labST:    .ascii "String too complex\0"
labCN:    .ascii "Can''t continue\0"
labUF:    .ascii "Undefined function\0"
labLD:    .ascii "LOOP without DO\0"
labUV:    .ascii "Undefined variable\0"
labUA:    .ascii "Undimensioned array\0"
labWD:    .ascii "Wrong dimensions\0"
labAD:    .ascii "Address\0"
labFO:    .ascii "Format\0"
labNI:    .ascii "Not implemented\0"


|************************************************************************************
|
| keyword table for line (un)crunching

| [keyword,token
| [keyword,token]]
| end marker (#0x00)

TAB_STAR:
KEY_MULT:
    dc.b TK_MULT,0x00                    | |
TAB_PLUS:
KEY_PLUS:
    dc.b TK_PLUS,0x00                    | +
TAB_MNUS:
KEY_MINUS:
    dc.b TK_MINUS,0x00                    | -
TAB_SLAS:
KEY_DIV:
    dc.b TK_DIV,0x00                    | /
TAB_LESS:
KEY_LSHIFT:
    dc.b    '<',TK_LSHIFT                | <<
KEY_LT:
    dc.b TK_LT                            | <
    dc.b    0x00
TAB_EQUL:
KEY_EQUAL:
    dc.b TK_EQUAL,0x00                    | =
TAB_MORE:
KEY_RSHIFT:
    dc.b    '>',TK_RSHIFT                | >>
KEY_GT:
    dc.b TK_GT                            | >
    dc.b    0x00
TAB_QEST:
    dc.b TK_PRINT,0x00                    | ?
TAB_ASCA:
KEY_ABS:
    .ascii  "BS("
    dc.b    TK_ABS                        | ABS(
KEY_and:
    .ascii "ND"
    dc.b   TK_AND    | and
KEY_ASC:
    .ascii "SC("
    dc.b   TK_ASC    | ASC(
KEY_ATN:
    .ascii "TN("
    dc.b   TK_ATN    | ATN(
    dc.b    0x00
TAB_ASCB:
KEY_BINS:
    .ascii "IN$("
    dc.b   TK_BINS    | BIN$(
KEY_BITCLR:
    .ascii "ITCLR"
    dc.b   TK_BITCLR    | BITCLR
KEY_BITSET:
    .ascii "ITSET"
    dc.b   TK_BITSET    | BITSET
KEY_BITTST:
    .ascii "ITTST("
    dc.b   TK_BITTST    | BITTST(
    dc.b    0x00
TAB_ASCC:
KEY_CALL:
    .ascii "ALL"
    dc.b   TK_CALL    | CALL
KEY_CHRS:
    .ascii "HR0x("
    dc.b   TK_CHRS    | CHR$(
KEY_CLEAR:
    .ascii "leaR"
    dc.b   TK_CLEAR    | CleaR
KEY_CONT:
    .ascii "ONT"
    dc.b   TK_CONT    | CONT
KEY_COS:
    .ascii "OS("
    dc.b   TK_COS    | COS(
    dc.b    0x00
TAB_ASCD:
KEY_DATA:
    .ascii "ATA"
    dc.b   TK_DATA    | DATA
KEY_DEC:
    .ascii "EC"
    dc.b   TK_DEC    | DEC
KEY_DEEK:
    .ascii "EEK("
    dc.b   TK_DEEK    | DEEK(
KEY_DEF:
    .ascii "EF"
    dc.b   TK_DEF    | DEF
KEY_DIM:
    .ascii "IM"
    dc.b   TK_DIM    | DIM
KEY_DOKE:
    .ascii "OKE"
    dc.b   TK_DOKE    | DOKE
KEY_DO:
    .ascii "O"
    dc.b   TK_DO    | DO
    dc.b    0x00
TAB_ASCE:
KEY_ELSE:
    .ascii "LSE"
    dc.b   TK_ELSE    | ELSE
KEY_END:
    .ascii "ND"
    dc.b   TK_END    | END
KEY_EOR:
    .ascii "OR"
    dc.b   TK_EOR    | eor
KEY_EXP:
    .ascii "XP("
    dc.b   TK_EXP    | EXP(
    dc.b    0x00
TAB_ASCF:
KEY_FOR:
    .ascii "OR"
    dc.b   TK_FOR    | FOR
KEY_FN:
    .ascii "N"
    dc.b   TK_FN    | FN
KEY_FRE:
    .ascii "RE("
    dc.b   TK_FRE    | FRE(
    dc.b    0x00
TAB_ASCG:
KEY_GET:
    .ascii "ET"
    dc.b   TK_GET    | GET
KEY_GOTO:
    .ascii "OTO"
    dc.b   TK_GOTO    | GOTO
KEY_GOSUB:
    .ascii "OSUB"
    dc.b   TK_GOSUB    | GOSUB
    dc.b    0x00
TAB_ASCH:
KEY_HEXS:
    .ascii "EX$("
    dc.b   TK_HEXS,0x00    | HEX$(
TAB_ASCI:
KEY_IF:
    .ascii "F"
    dc.b   TK_IF    | IF
KEY_INC:
    .ascii "NC"
    dc.b   TK_INC    | INC
KEY_INPUT:
    .ascii "NPUT"
    dc.b   TK_INPUT    | INPUT
KEY_INT:
    .ascii "NT("
    dc.b   TK_INT    | INT(
    dc.b    0x00
TAB_ASCL:
KEY_LCASES:
    .ascii "CASE$("
    dc.b   TK_LCASES    | LCASE0x(
KEY_LEEK:
    .ascii "EEK("
    dc.b   TK_LEEK    | LEEK(
KEY_LEFTS:
    .ascii "EFT$("
    dc.b   TK_LEFTS    | LEFT$(
KEY_LEN:
    .ascii "EN("
    dc.b   TK_LEN    | LEN(
KEY_LET:
    .ascii "ET"
    dc.b   TK_LET    | LET
KEY_LIST:
    .ascii "IST"
    dc.b   TK_LIST    | LIST
KEY_LOAD:
    .ascii "OAD"
    dc.b   TK_LOAD    | LOAD
KEY_LOG:
    .ascii "OG("
    dc.b   TK_LOG    | LOG(
KEY_LOKE:
    .ascii "OKE"
    dc.b   TK_LOKE    | LOKE
KEY_LOOP:
    .ascii "OOP"
    dc.b   TK_LOOP    | LOOP
    dc.b    0x00
TAB_ASCM:
KEY_MAX:
    .ascii "AX("
    dc.b   TK_MAX    | MAX(
KEY_MIDS:
    .ascii "ID$("
    dc.b   TK_MIDS    | MID$(
KEY_MIN:
    .ascii "IN("
    dc.b   TK_MIN    | MIN(
    dc.b    0x00
TAB_ASCN:
KEY_NEW:
    .ascii "EW"
    dc.b   TK_NEW    | NEW
KEY_Next:
    .ascii "EXT"
    dc.b   TK_Next    | Next
KEY_NOT:
    .ascii "OT"
    dc.b   TK_NOT    | NOT
KEY_NULL:
    .ascii "ULL"
    dc.b   TK_NULL    | NULL
    dc.b    0x00
TAB_ASCO:
KEY_ON:
    .ascii "N"
    dc.b   TK_ON    | ON
KEY_OR:
    .ascii "R"
    dc.b   TK_OR    | OR
    dc.b    0x00
TAB_ASCP:
KEY_PEEK:
    .ascii "EEK("
    dc.b   TK_PEEK    | PEEK(
KEY_PI:
    .ascii "I"
    dc.b   TK_PI    | PI
KEY_POKE:
    .ascii "OKE"
    dc.b   TK_POKE    | POKE
KEY_POS:
    .ascii "OS("
    dc.b   TK_POS    | POS(
KEY_PRINT:
    .ascii "RINT"
    dc.b   TK_PRINT    | PRINT
    dc.b    0x00
TAB_ASCR:
KEY_RAM:
    .ascii "AMBASE"
    dc.b   TK_RAM    | RAMBASE
KEY_READ:
    .ascii "EAD"
    dc.b   TK_READ    | READ
KEY_REM:
    .ascii "EM"
    dc.b   TK_REM    | REM
KEY_RESTORE:
    .ascii "ESTORE"
    dc.b   TK_RESTORE    | RESTORE
KEY_RETURN:
    .ascii "ETURN"
    dc.b   TK_RETURN    | RETURN
KEY_RIGHTS:
    .ascii "IGHT$("
    dc.b   TK_RIGHTS    | RIGHT$(
KEY_RND:
    .ascii "ND("
    dc.b   TK_RND    | RND(
KEY_RUN:
    .ascii "UN"
    dc.b   TK_RUN    | RUN
    dc.b    0x00
TAB_ASCS:
KEY_SADD:
    .ascii "add("
    dc.b   TK_Sadd    | Sadd(
KEY_SAVE:
    .ascii "AVE"
    dc.b   TK_SAVE    | SAVE
KEY_SGN:
    .ascii "GN("
    dc.b   TK_SGN    | SGN(
KEY_SIN:
    .ascii "IN("
    dc.b   TK_SIN    | SIN(
KEY_SPC:
    .ascii "PC("
    dc.b   TK_SPC    | SPC(
KEY_SQR:
    .ascii "QR("
    dc.b   TK_SQR    | SQR(
KEY_STEP:
    .ascii "TEP"
    dc.b   TK_STEP    | STEP
KEY_STOP:
    .ascii "TOP"
    dc.b   TK_STOP    | STOP
KEY_STRS:
    .ascii "TR$("
    dc.b   TK_STRS    | STR$(
KEY_SWAP:
    .ascii "WAP"
    dc.b   TK_SWAP    | swap
    dc.b    0x00
TAB_ASCT:
KEY_TAB:
    .ascii "AB("
    dc.b   TK_TAB    | TAB(
KEY_TAN:
    .ascii "AN("
    dc.b   TK_TAN    | TAN
KEY_THEN:
    .ascii "HEN"
    dc.b   TK_THEN    | THEN
KEY_TO:
    .ascii "O"
    dc.b   TK_TO    | TO
KEY_TWOPI:
    .ascii "WOPI"
    dc.b   TK_TWOPI    | TWOPI
    dc.b    0x00
TAB_ASCU:
KEY_UCASES:
    .ascii "CASE$("
    dc.b   TK_UCASES    | UCASE0x(
KEY_UNTIL:
    .ascii "NTIL"
    dc.b   TK_UNTIL    | UNTIL
KEY_USINGS:
    .ascii "SING$("
    dc.b   TK_USINGS    | USING$(
KEY_USR:
    .ascii "SR("
    dc.b   TK_USR    | USR(
    dc.b    0x00
TAB_ASCV:
KEY_VAL:
    .ascii "AL("
    dc.b   TK_VAL    | VAL(
KEY_VPTR:
    .ascii "ARPTR("
    dc.b   TK_VPTR    | VARPTR(
    dc.b    0x00
TAB_ASCW:
KEY_WAIT:
    .ascii "AIT"
    dc.b   TK_WAIT    | WAIT
KEY_WHILE:
    .ascii "HILE"
    dc.b   TK_WHILE    | WHILE
KEY_WIDTH:
    .ascii "IDTH"
    dc.b   TK_WIDTH    | WIDTH
    dc.b    0x00
TAB_POWR:
KEY_POWER:
    dc.b    TK_POWER,0x00    | ^


|************************************************************************************
|
| just messages

labBMSG:
    .ascii    "\r\nBreak\0"
labEMSG:
    .ascii    " Error\0"
labLMSG:
    .ascii    " in line \0"
labIMSG:
    .ascii    "Extra ignored\r\n\0"
labREDO:
    .ascii    "Redo from start\r\n\0"
labRMSG:
    .ascii    "\r\nReady\r\n\0"
labSMSG:
    .ascii    " Bytes free\r\n"
    .ascii    "Enhanced 68k BASIC Version 3.52\r\n\0"


|************************************************************************************
| EhBASIC keywords quick reference list    |
|************************************************************************************

| glossary

|    <.>    required
|    {.|.}    one of required
|    [.]    optional
|    ...    may repeat as last

|    any    = anything
|    num    = number
|    state    = statement
|    n    = positive integer
|    str    = string
|    var    = variable
|    nvar    = numeric variable
|    svar    = string variable
|    expr    = expression
|    nexpr    = numeric expression
|    sexpr    = string expression

| statement separator

| :    . [<state>] : [<state>]    | done

| number bases

| %    . %<binary num>    | done
| 0x    . 0x<hex num>    | done

| commands

| END    . END    | done
| FOR    . FOR <nvar>=<nexpr> TO <nexpr> [STEP <nexpr>]    | done
| Next    . Next [<nvar>[,<nvar>]...]    | done
| DATA    . DATA [{num|["]str["]}[,{num|["]str["]}]...]    | done
| INPUT    . INPUT [<">str<">|] <var>[,<var>[,<var>]...]    | done
| DIM    . DIM <var>(<nexpr>[,<nexpr>[,<nexpr>]])    | done
| READ    . READ <var>[,<var>[,<var>]...]    | done
| LET    . [LET] <var>=<expr>    | done
| DEC    . DEC <nvar>[,<nvar>[,<nvar>]...]    | done
| GOTO    . GOTO <n>    | done
| RUN    . RUN [<n>]    | done
| IF    . IF <expr>{GOTO<n>|THEN<{n|comm}>}[ELSE <{n|comm}>]    | done
| RESTORE    . RESTORE [<n>]    | done
| GOSUB    . GOSUB <n>    | done
| RETURN    . RETURN    | done
| REM    . REM [<any>]    | done
| STOP    . STOP    | done
| ON    . ON <nexpr>{GOTO|GOSUB}<n>[,<n>[,<n>]...]    | done
| NULL    . NULL <nexpr>    | done
| INC    . INC <nvar>[,<nvar>[,<nvar>]...]    | done
| WAIT    . WAIT <nexpr>,<nexpr>[,<nexpr>]    | done
| LOAD    . LOAD [<sexpr>]    | done for sim
| SAVE    . SAVE [<sexpr>][,[<n>][-<n>]]    | done for sim
| DEF    . DEF FN<var>(<var>)=<expr>    | done
| POKE    . POKE <nexpr>,<nexpr>    | done
| DOKE    . DOKE <nexpr>,<nexpr>    | done
| LOKE    . LOKE <nexpr>,<nexpr>    | done
| CALL    . CALL <nexpr>    | done
| DO    . DO    | done
| LOOP    . LOOP [{WHILE|UNTIL}<nexpr>]    | done
| PRINT    . PRINT [{||,}][<expr>][{||,}[<expr>]...]    | done
| CONT    . CONT    | done
| LIST    . LIST [<n>][-<n>]    | done
| CleaR    . CleaR    | done
| NEW    . NEW    | done
| WIDTH    . WIDTH [<n>][,<n>]    | done
| GET    . GET <var>    | done
| swap    . swap <var>,<var>    | done
| BITSET    . BITSET <nexpr>,<nexpr>    | done
| BITCLR    . BITCLR <nexpr>,<nexpr>    | done

| sub commands (may not start a statement)

| TAB    . TAB(<nexpr>)    | done
| ELSE    . IF <expr>{GOTO<n>|THEN<{n|comm}>}[ELSE <{n|comm}>]    | done
| TO    . FOR <nvar>=<nexpr> TO <nexpr> [STEP <nexpr>]    | done
| FN    . FN <var>(<expr>)    | done
| SPC    . SPC(<nexpr>)    | done
| THEN    . IF <nexpr> {THEN <{n|comm}>|GOTO <n>}    | done
| NOT    . NOT <nexpr>    | done
| STEP    . FOR <nvar>=<nexpr> TO <nexpr> [STEP <nexpr>]    | done
| UNTIL    . LOOP [{WHILE|UNTIL}<nexpr>]    | done
| WHILE    . LOOP [{WHILE|UNTIL}<nexpr>]    | done

| operators

| +    . [expr] + <expr>    | done
| -    . [nexpr] - <nexpr>    | done
| |    . <nexpr> | <nexpr>    | done fast hardware
| /    . <nexpr> / <nexpr>    | done fast hardware
| ^    . <nexpr> ^ <nexpr>    | done
| and    . <nexpr> and <nexpr>    | done
| eor    . <nexpr> eor <nexpr>    | done
| OR    . <nexpr> OR <nexpr>    | done
| >>    . <nexpr> >> <nexpr>    | done
| <<    . <nexpr> << <nexpr>    | done

| compare functions

| <    . <expr> < <expr>    | done
| =    . <expr> = <expr>    | done
| >    . <expr> > <expr>    | done

| functions

| SGN    . SGN(<nexpr>)    | done
| INT    . INT(<nexpr>)    | done
| ABS    . ABS(<nexpr>)    | done
| USR    . USR(<expr>)    | done
| FRE    . FRE(<expr>)    | done
| POS    . POS(<expr>)    | done
| SQR    . SQR(<nexpr>)    | done fast shift/sub
| RND    . RND(<nexpr>)    | done 32 bit PRNG
| LOG    . LOG(<nexpr>)    | done fast cordic
| EXP    . EXP(<nexpr>)    | done fast cordic
| COS    . COS(<nexpr>)    | done fast cordic
| SIN    . SIN(<nexpr>)    | done fast cordic
| TAN    . TAN(<nexpr>)    | done fast cordic
| ATN    . ATN(<nexpr>)    | done fast cordic
| PEEK    . PEEK(<nexpr>)    | done
| DEEK    . DEEK(<nexpr>)    | done
| LEEK    . LEEK(<nexpr>)    | done
| LEN    . LEN(<sexpr>)    | done
| STR$    . STR$(<nexpr>)    | done
| VAL    . VAL(<sexpr>)    | done
| ASC    . ASC(<sexpr>)    | done
| UCASE$    . UCASE0x(<sexpr>)    | done
| LCASE$    . LCASE0x(<sexpr>)    | done
| CHR$    . CHR$(<nexpr>)    | done
| HEX$    . HEX$(<nexpr>)    | done
| BIN$    . BIN$(<nexpr>)    | done
| BTST    . BTST(<nexpr>,<nexpr>)    | done
| MAX    . MAX(<nexpr>[,<nexpr>[,<nexpr>]...])    | done
| MIN    . MIN(<nexpr>[,<nexpr>[,<nexpr>]...])    | done
| PI    . PI    | done
| TWOPI    . TWOPI    | done
| VARPTR    . VARPTR(<var>)    | done
| Sadd    . Sadd(<svar>)    | done
| LEFT$    . LEFT$(<sexpr>,<nexpr>)    | done
| RIGHT$    . RIGHT$(<sexpr>,<nexpr>)    | done
| MID$    . MID$(<sexpr>,<nexpr>[,<nexpr>])    | done
| USING$    . USING$(<sexpr>,<nexpr>[,<nexpr>]...])    | done


|************************************************************************************

|    END    code_start

|************************************************************************************
