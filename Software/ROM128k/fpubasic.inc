| This is the layout of global variables in memory.
| Origin should be left at zero (ORG 0), and ram_addr at the bottom should 
| be set to the lowest available memory address (making room for vector table
| or monitor code as needed).
    .section bss,"w"
 
ram_strt:	ds.l	0x100	| allow 1K for the stack, this should be plenty
            | for any BASIC program that doesnt do something
            | silly, it could even be much less.
ram_base:	| this gets loaded as the stack pointer
labWARM:	ds.w	1	| BASIC warm start entry point
Wrmjpv:	ds.l	1	| BASIC warm start jump vector

Usrjmp:	ds.w	1	| USR function JMP address
Usrjpv:	ds.l	1	| USR function JMP vector

| system dependant i/o vectors
| these are in RAM and are set at start-up

V_INPT:	ds.w	1	| non halting scan input device entry point
V_INPTv:	ds.l	1	| non halting scan input device jump vector

V_OUTP:	ds.w	1	| send byte to output device entry point
V_OUTPv:	ds.l	1	| send byte to output device jump vector

V_LOAD:	ds.w	1	| load BASIC program entry point
V_LOADv:	ds.l	1	| load BASIC program jump vector

V_SAVE:	ds.w	1	| save BASIC program entry point
V_SAVEv:	ds.l	1	| save BASIC program jump vector

V_CTLC:	ds.w	1	| save CTRL-C check entry point
V_CTLCv:	ds.l	1	| save CTRL-C check jump vector

Itemp:	ds.l	1	| temporary integer	(for GOTO etc)

Smeml:	ds.l	1	| start of memory	(start of program)

| the program is stored as a series of lines each line having the following format
|
|	ds.l	1	| pointer to the next line or $00000000 if [EOT]
|	ds.l	1	| line number
|	ds.b	n	| program bytes
|	dc.b	$00	| [EOL] marker, there will be a second $00 byte, if
|	| needed, to pad the line to an even number of bytes

Sfncl:	ds.l	1	| start of functions	(end of Program)

| the functions are stored as function name, function execute pointer and function
| variable name
|
|	ds.l	1	| name
|	ds.l	1	| execute pointer
|	ds.l	1	| function variable

Svarl:	ds.l	1	| start of variables	(end of functions)

| the variables are stored as variable name, variable value
|
|	ds.l	1	| name
|	ds.l	1	| packed float or integer value

Sstrl:	ds.l	1	| start of strings	(end of variables)

| the strings are stored as string name, string pointer and string length
|
|	ds.l	1	| name
|	ds.l	1	| string pointer
|	ds.w	1	| string length

Sarryl:	ds.l	1	| start of arrays	(end of strings)

| the arrays are stored as array name, array size, array dimensions count, array
| dimensions upper bounds and array elements
|
|	ds.l	1	| name
|	ds.l	1	| size including this header
|	ds.w	1	| dimensions count
|	ds.w	1	| 1st dimension upper bound
|	ds.w	1	| 2nd dimension upper bound
|	...	| ...
|	ds.w	1	| nth dimension upper bound
|
| then (i1+1)|(i2+1)...|(in+1) of either ..
|
|	ds.l	1	| packed float or integer value
|
| .. if float or integer, or ..
|
|	ds.l	1	| string pointer
|	ds.w	1	| string length
|
| .. if string

Earryl:	ds.l	1	| end of arrays	(start of free mem)
Sstorl:	ds.l	1	| string storage	(moving down)
Ememl:	ds.l	1	| end of memory	(upper bound of RAM)
Sutill:	ds.l	1	| string utility ptr
Clinel:	ds.l	1	| current line	(Basic line number)
Blinel:	ds.l	1	| break line	(Basic line number)

Cpntrl:	ds.l	1	| continue pointer
Dlinel:	ds.l	1	| current DATA line
Dptrl:	ds.l	1	| DATA pointer
Rdptrl:	ds.l	1	| read pointer
Varname:	ds.l	1	| current var name
Cvaral:	ds.l	1	| current var address
Lvarpl:	ds.l	1	| variable pointer for LET and FOR/NEXT

des_sk_e:	ds.l	6	| descriptor stack end address
des_sk:			| descriptor stack start address
            | use a4 for the descriptor pointer
    ds.w	1	
Ibuffs:	ds.l	0x40	| start of input buffer
Ibuffe:
            | end of input buffer

FAC1_m:	ds.l	1	| FAC1 mantissa1
FAC1_e:	ds.w	1	| FAC1 exponent

    .equ FAC1_s,FAC1_e+1	| FAC1 sign (b7)
    ds.w	1	

FAC2_m:	ds.l	1	| FAC2 mantissa1
FAC2_e:	ds.l	1	| FAC2 exponent
|FAC2_s	EQU	FAC2_e+1	| FAC2 sign (b7)
|FAC_sc	EQU	FAC2_e+2	| FAC sign comparison, Acc#1 vs #2
|flag	EQU	FAC2_e+3	| flag byte for divide routine
    .equ FAC2_s,FAC2_e+1				| FAC2 sign(b7)
    .equ FAC_sc,FAC2_e+2				| FAC sign comparison, Acc#1 vs #2
    .equ flag,FAC2_e+3					| flag byte for divide routine

PRNlword:	ds.l	1	| PRNG seed long word

ut1_pl:	ds.l	1	| utility pointer 1

Asptl:	ds.l	1	| array size/pointer
Astrtl:	ds.l	1	| array start pointer

|numexp:	EQU	Astrtl	| string to float number exponent count
|expcnt:	EQU	Astrtl+1	| string to float exponent count
|expneg:	EQU	Astrtl+3	| string to float eval exponent -ve flag

    .equ numexp,Astrtl					| string to float number exponent count
    .equ expcnt,Astrtl+1				| string to float exponent count
    .equ expneg,Astrtl+3				| string to float eval exponent -ve flag


func_l:	ds.l	1	| function pointer

    .even
| these two need to be a word aligned pair !
Defdim:	ds.w	1						| default DIM flag
|cosout	EQU	Defdim	| flag which CORDIC output (re-use byte)
|Dtypef	EQU	Defdim+1	| data type flag, $80=string, $40=integer, $00=float
    .equ cosout,Defdim					| flag which CORDIC output (re-use byte)
    .equ Dtypef,Defdim+1				| data type flag, $80=string, $40=integer, $00=float


Binss:	ds.l	4	| number to bin string start (32 chrs)

Decss:	ds.l	1	| number to decimal string start (16 chrs)
        ds.w	1	|
Usdss:	ds.w	1	| unsigned decimal string start (10 chrs)

Hexss:	ds.l	2	| number to hex string start (8 chrs)

BHsend:	ds.w	1	| bin/decimal/hex string end


prstk:	ds.b	1	| stacked function index

tpower:	ds.b	1	| remember CORDIC power

Asrch:	ds.b	1	| scan-between-quotes flag, alt search character

Dimcnt:	ds.b	1	| # of dimensions

Breakf:	ds.b	1	| break flag, $00=END else=break
Oquote:	ds.b	1	| open quote flag (Flag: DATA| LIST| memory)
Gclctd:	ds.b	1	| garbage collected flag
Sufnxf:	ds.b	1	| subscript/FNX flag, 1xxx xxx = FN(0xxx xxx)
Imode:	ds.b	1	| input mode flag, $00=INPUT, $98=READ

Cflag:	ds.b	1	| comparison evaluation flag

TabSiz:	ds.b	1	| TAB step size

comp_f:	ds.b	1	| compare function flag, bits 0,1 and 2 used
                    | bit 2 set if >
                    | bit 1 set if =
                    | bit 0 set if <

Nullct:	ds.b	1	| nulls output after each line
TPos:	ds.b	1	| BASIC terminal position byte
TWidth:	ds.b	1	| BASIC terminal width byte
Iclim:	ds.b	1	| input column limit
ccflag:	ds.b	1	| CTRL-C check flag
ccbyte:	ds.b	1	| CTRL-C last received byte
ccnull:	ds.b	1	| CTRL-C last received byte 'life' timer

| these variables for simulator load/save routines

file_byte:	ds.b	1	| load/save data byte
file_id:	ds.l	1	| load/save file ID

| add a flag for FPU presence
flagFPU:	ds.b	1

    .even

| here we will save some pointers for common functions used by external calls

prg_strt:

| These values are set for BASIC running straight from ROM.
| When loaded into RAM with an external loader, it is the responsibility
| of the external loader to set the appropriate values in the designated 
| registers. 
|ram_addr:	EQU	$00001000	| RAM past Monitor heap (A0)
|ram_size:	EQU	$001FF000	| RAM Size Free (D0)

    .ifdef  debug
| debugging macros

| print the current Program counter
| this is expensive in terms of resources used, but helpful for debugging
    .macro debugPrintPC
    movem.l %a0-%a6/%d0-%d7,%sp@-       | save all registers first
    lea     %pc@(-6),%a0                | get current PC before macro
    move.l  %a0,%sp@-                   | and save it
    moveq   #2,%d1                      | trap 0 call 2 for print newline
    trap    #0                          | call the trap
    move.l  %sp@+,%d0                   | recover the PC we saved
    moveq   #0xb,%d1                    | trap 0 call B for print hex long
    trap    #0                          | call the trap
    movem.l %sp@+,%a0-%a6/%d0-%d7       | restore all registers
    .endm

| call TSMON print hex long trap for specified register
    .macro sysPutHexLong regIn
    movem.l %a0-%a6/%d0-%d7,%sp@-       | save all registers first
    move.l  \regIn,%d0                  | copy selected register to D0
    moveq   #0xB,%d1                    | trap 0 call B for print Hex Long
    trap    #0                          | call the trap
    movem.l %sp@+,%a0-%a6/%d0-%d7       | restore all registers
    .endm

    .macro debugPrintD0
    movem.l %a0-%a6/%d0-%d7,%sp@-       | save all registers first
    lea     %pc@(L\@D0s),%a4            | get header string
    moveq   #4,%d1                      | trap 0 call 4 for print string
    trap    #0                          | call the trap
    move.l  %sp@(0x00),%d0              | restore D0 value
    moveq   #0xB,%d1                    | trap 0 call B for print Hex Long
    trap    #0                          | call the trap
    bra.s   L\@D0End                    | skip over string
L\@D0s:
    .ascii  "\r\nD0:   $\0"
    .even
L\@D0End:
    movem.l %sp@+,%a0-%a6/%d0-%d7       | restore all registers
    .endm

    .macro debugPrintFAC1
    movem.l %a0-%a6/%d0-%d7,%sp@-       | save all registers first
    lea     %pc@(L\@FAC1s),%a4          | get header string
    moveq   #4,%d1                      | trap 0 call 4 for print string
    trap    #0                          | call the trap
    move.l  %sp@(0x2c),%a3              | restore A3 just in case
    move.l  %a3@(FAC1_m),%d0            | get mantissa
    moveq   #0xB,%d1                    | trap 0 call B for print Hex Long
    trap    #0                          | call the trap
    moveq   #'$',%d0                    | print a $ as a divider
    moveq   #1,%d1                      | trap 0 call 1 for print char
    trap    #0                          | call the trap
    move.l  %sp@(0x2c),%a3              | restore A3 just in case
    move.w  %a3@(FAC1_e),%d0            | get sign & exponent
    moveq   #0xA,%d1                    | trap 0 call A for print Hex word
    trap    #0                          | call the trap
    bra.s   L\@F1End                    | skip over string
L\@FAC1s:
    .ascii  "\r\nFAC1: $\0"
    .even
L\@F1End:
    movem.l %sp@+,%a0-%a6/%d0-%d7       | restore all registers
    .endm

    .macro debugPrintFAC2
    movem.l %a0-%a6/%d0-%d7,%sp@-       | save all registers first
    lea     %pc@(L\@FAC2s),%a4          | get header string
    moveq   #4,%d1                      | trap 0 call 4 for print string
    trap    #0                          | call the trap
    move.l  %sp@(0x2c),%a3              | restore A3 just in case
    move.l  %a3@(FAC2_m),%d0            | get mantissa
    moveq   #0xB,%d1                    | trap 0 call B for print Hex Long
    trap    #0                          | call the trap
    moveq   #'$',%d0                    | print a $ as a divider
    moveq   #1,%d1                      | trap 0 call 1 for print char
    trap    #0                          | call the trap
    move.l  %sp@(0x2c),%a3              | restore A3 just in case
    move.w  %a3@(FAC2_e),%d0            | get sign & exponent
    moveq   #0xA,%d1                    | trap 0 call A for print Hex word
    trap    #0                          | call the trap
    bra     L\@F2End                    | skip over string
L\@FAC2s:
    .ascii  "\r\nFAC2: $\0"
    .even
L\@F2End:
    movem.l %sp@+,%a0-%a6/%d0-%d7       | restore all registers
    .endm

| end debugging macros
    .endif

| macros for converting between EhBASIC floats & IEEE-754 single-precision
| to convert to IEEE-754:
|   subtract 2 from exponent
|   mask high bit of mantissa
| to convert to EhBASIC:
|   add 2 to exponent
|   normalize such that first bit of mantissa is 1

| get FAC1 & format as Single-Precision Float in D0
    .macro FAC1toD0
    move.l  %d1,%sp@-                   | save D1
    .ifdef  debug
    movem.l %a0-%a6/%d0-%d7,%sp@-       | save all registers first
    lea     %pc@(L\@F1D0s),%a4          | load pointer to header string
    moveq   #4,%d1                      | trap 0 call 4 for print string
    trap    #0                          | call the trap
    bra.s   L\@F1D0End                  | skip over header string
L\@F1D0s:
    .ascii  "\r\nFAC1toD0: \0"
    .even
L\@F1D0End:
    movem.l %sp@+,%a0-%a6/%d0-%d7       | restore all registers
    debugPrintFAC1
    .endif
    move.l  %a3@(FAC1_m),%d0            | get mantissa
    lsr.l   #8,%d0                      | shift mantissa into position
    swap    %d0                         | word swap
    andi.w  #0x7f,%d0                   | mask out sign & exponent bits
    move.w  %a3@(FAC1_e),%d1            | get sign & exponent
    lsr.b   #7,%d1                      | move sign to LSB
    ror.w   #8,%d1                      | swap position of sign & exponent
    subq.b  #2,%d1                      | subtract 2 from exponent
    lsl.w   #7,%d1                      | shift sign & exponent into position
    or.w    %d1,%d0                     | combine s&e with mantissa
    swap    %d0                         | revert word order
    .ifdef  debug
    debugPrintD0
    .endif
    move.l  %sp@+,%d1                   | restore D1
    .endm

| get FAC2 & format as Single-Precision Float in D0
    .macro FAC2toD0
    move.l  %d1,%sp@-                   | save D1
    .ifdef  debug
    movem.l %a0-%a6/%d0-%d7,%sp@-       | save all registers first
    lea     %pc@(L\@F1D0s),%a4          | load pointer to header string
    moveq   #4,%d1                      | trap 0 call 4 for print string
    trap    #0                          | call the trap
    bra.s   L\@F1D0End                  | skip over header string
L\@F1D0s:
    .ascii  "\r\nFAC2toD0: \0"
    .even
L\@F1D0End:
    movem.l %sp@+,%a0-%a6/%d0-%d7       | restore all registers
    debugPrintFAC2
    .endif
    move.l  %a3@(FAC2_m),%d0            | get mantissa
    lsr.l   #8,%d0                      | shift mantissa into position
    swap    %d0                         | word swap
    andi.w  #0x7f,%d0                   | mask out sign & exponent bits
    move.w  %a3@(FAC2_e),%d1            | get sign & exponent
    lsr.b   #7,%d1                      | move sign to LSB
    ror.w   #8,%d1                      | swap position of sign & exponent
    subq.b  #2,%d1                      | subtract 2 from exponent
    lsl.w   #7,%d1                      | shift sign & exponent into position
    or.w    %d1,%d0                     | combine s&e with mantissa
    swap    %d0                         | revert word order
    .ifdef  debug
    debugPrintD0
    .endif
    move.l  %sp@+,%d1                   | restore D1
    .endm

| get Single-Precision Float in D0 & save to FAC1
| by first converting to EhBASIC packed float
    .macro D0toFAC1
    move.l %d1,%sp@-                    | first save D1
    .ifdef debug
    movem.l %a0-%a6/%d0-%d7,%sp@-       | save all registers first
    lea     %pc@(L\@F1D0s),%a4          | load pointer to header string
    moveq   #4,%d1                      | trap 0 call 4 for print string
    trap    #0                          | call the trap
    bra.s   L\@F1D0End                  | skip over header string
L\@F1D0s:
    .ascii  "\r\nD0toFAC1: \0"
    .even
L\@F1D0End:
    movem.l %sp@+,%a0-%a6/%d0-%d7       | restore all registers
    debugPrintD0
    .endif
    swap   %d0                          | reverse byte order
    move.w %d0,%d1                      | get sign & exponent in D1
    ror.w  #7,%d1                       | move exponent into low byte
    addq.b #2,%d1                       | add 2 to exponent
    rol.w  #8,%d1                       | move exponent into high byte
    lsl.b  #7,%d1                       | move sign into MSB of low byte
    andi.w #0x7f,%d0                    | mask out space for sign & exponent
    or.w   %d1,%d0                      | combine s&e with mantissa

    move.w %d0,%a3@(FAC1_e)             | save exponent & sign
    beq.s  L\@NB1T                      | skip ahead if exponent is zero
    or.w   #0x80,%d0                    | set MSB
    swap   %d0                          | revert word order
    asl.l  #8,%d0                       | shift exponent & clear guard byte
L\@NB1T:
    move.l %d0,%a3@(FAC1_m)             | move mantissa into FAC1
    move.b %a3@(FAC1_e),%d0             | get FAC1 exponent
    .ifdef  debug
    debugPrintFAC1
    .endif
    move.l %sp@+,%d1                    | restore D1
    .endm


| get 32-bit Single-Precision in D0 & save to FAC1
|    .macro D0toFAC1
|    swap	%d0
|    move.w  %d0,%a3@(FAC1_e)
|    beq.s   L\@NB1T
|    or.w    #0x80,%d0
|    swap    %d0
|    asl.l   #8,%d0
|L\@NB1T:
|    move.l  %d0,%a3@(FAC1_m)
|    .endm

| get FAC1 & format as 32-bit Single-Precision in D0
|	.macro FAC1toD0
|	move.l	%a3@(FAC1_m),%d0
|	ror.l   #8,%d0
|	swap    %d0
|	and.w   #0x7F,%d0
|	andi.b  #0x80,%a3@(FAC1_s)
|	or.w    %a3@(FAC1_e),%d0
|	swap    %d0
|	.endm
| get FAC2 & format as 32-bit Single-Precision in D0
|	.macro FAC2toD0
|	move.l  %a3@(FAC2_m),%d0
|	ror.l   #8,%d0
|	swap    %d0
|	and.w   #0x7f,%d0
|	andi.b  #0x80,%a3@(FAC2_s)
|	or.w    %a3@(FAC2_e),%d0
|	swap    %d0
|	.endm

| check FPU presence flag
    .macro FPUTEST
    move.b	%a3@(flagFPU),%d0	| get FPU presence flag
    cmpi.b  #1,%d0				| check FPU flag
    .endm
