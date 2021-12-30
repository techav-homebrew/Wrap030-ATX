;******************************************************************************
;* Wrap030 TSMON Expansion ROM
;* techav
;* 2021-12-26
;******************************************************************************
;* Provides additional commands for TSMON ROM monitor
;*****************************************************************************/

            INCLUDE "TSMON_Constants.INC"

ROMBASIC:   EQU romSector7  ; address for BASIC in ROM
RAMBASIC:   EQU ramBot+$1000    ; above vector table & TSMON globals
HEAPBASIC:  EQU RAMBASIC+$4000  ; above BASIC program in RAM
SIZBASIC:   EQU $4000       ; total size of BASIC to copy from ROM (~16kB)

PSTRING:    EQU $002004B6   ; I really need a good linker ...

    ORG	expROM
; This is loaded by TSMON on startup to confirm an expansion ROM is installed
EXTROM:	
    DC.L	'ROM2'	        ;Expansion ROM identification
    DC.L	0

; This is called by TSMON on startup to allow the expansion ROM to initialize
; anything it may need to initialize on startup.
RM2INIT:	
    LEA	    DATA,A6	        ;A6 points to RAM heap
    LEA	    UCOM,A5	        ;A5 points to User Command Table
    MOVE.L  A5,UTAB(A6)	    ;Copy User Com Table ptr
    LEA	    sBNR(PC),A4     ;Get pointer to banner string
    JSR	    PSTRING	        ;Print header string
    BSR     ucCEnable       ;enable cache by default
    RTS

; This is our Help function which prints out a list of commands supported by 
; TSMON and this expansion ROM
ucHELP:	
    LEA	    sHELP(PC),A4	;Get pointer to help text string
    JSR	    PSTRING	        ;Print help text string
    RTS

; This function will load BASIC from ROM into RAM and jump to it.
ucLoadBasic:                ; load BASIC into RAM and execute
    MOVEM.L A0-A7/D0-D7,-(A7)   ; save all registers in case we make it back here
    LEA     sBAS1(PC),A4    ; get pointer to header text string
    JSR     PSTRING         ; print header text string
.startCopy:
    LEA     ROMBASIC,A0     ; get pointer to BASIC in ROM
    LEA     RAMBASIC,A1     ; get pointer to RAM above vector table
    MOVE.L  #SIZBASIC>>2,D0 ; number of longwords to copy 
                            ; (NEED BETTER WAY TO GET THIS NUMBER)
.copyLoop:
    MOVE.L  (A0)+,(A1)+     ; copy BASIC into RAM, one Longword at a time
    DBRA    D0,.copyLoop    ; keep copying until finished
    LEA     sBAS2(PC),A4    ; get pointer to verifying string
    JSR     PSTRING         ; print string
.startVerify:
    LEA     ROMBASIC,A0
    LEA     RAMBASIC,A1
    MOVE.L  #SIZBASIC>>2,D0
.verifyLoop:
    MOVE.L  (A0)+,D1
    MOVE.L  (A1)+,D2
    CMP.L   D1,D2
    BNE     vErrrr
    DBRA    D0,.verifyLoop
.verifyGood:
    LEA     sBAS3(PC),A4    ; get pointer to verify good string
    JSR     PSTRING         ; and print
    EOR.L   D0,D0           ; clear D0
    LEA     RAMBASIC,A1     ; get pointer to BASIC in RAM
    MOVE.W  $E(A1),D0       ; get offset for BASIC cold start routine
    LEA     0(A1,D0),A1     ; get address of BASIC cold start routine
; we need base heap address in A0 and free RAM in D0
    LEA     HEAPBASIC,A0    ; get bottom free memory after BASIC program
    MOVE.L  SP,D0           ; get current stack pointer (top of free RAM)
    SUBI.L  #4,D0            ; make room for our return address
    SUB.L   A0,D0           ; get current RAM free
    JSR     (A1)            ; jump to BASIC in RAM
    MOVEM.L (A7)+,A0-A7/D0-D7   ; by some miracle we've come back.
    RTS                     ; Restore registers and return

vErrrr:
; BASIC in RAM does not match BASIC in ROM
    LEA     sBASerr(PC),A4  ; get pointer to error string
    JSR     PSTRING         ; print error
    MOVEM.L (A7)+,A0-A7/D0-D7   ; restore saved registers
    RTS                     ; and return to TSMON

; Enable 68030 cache
ucCEnable:
    MOVEM.L A4/D0,-(A7)     ; save working registers
    MOVE.L  #00000101,D0    ; enable data & instruction cache
    DC.L    $4e7b0002       ; movec D0,CACR
    LEA     sCEN(PC),A4     ; get pointer to feedback string
    JSR     PSTRING         ; and print
    MOVEM.L (A7)+,D0/A4     ; restore working registers
    RTS

; Disable 68030 cache
ucCDisable:
    MOVEM.L A4/D0,-(A7)     ; save working registers
    EOR.L   D0,D0           ; disable data & instruction cache
    DC.L    $4e7b0002       ; movec D0,CACR
    LEA     sCDIS(PC),A4    ; get pointer to feedback string
    JSR     PSTRING         ; and print
    MOVEM.L (A7)+,D0/A4     ; restore working registers
    RTS


;User Command Table
UCOM:	
    DC.B	4,4
    DC.B	'HELP'
    DC.L	ucHELP
    DC.B	6,3
    DC.B	'BASIC '
    DC.L	ucLoadBasic
    DC.B    8,3
    DC.B    'CENABLE '
    DC.L    ucCEnable
    DC.B    8,4
    DC.B    'CDISABLE'
    DC.L    ucCDisable
    DC.B	0,0
;String Constants
sBNR:	DC.B	'ROM2 Loaded.',0,0

sHELP:	DC.B	'Available Commands:',$0D,$0A
    DC.B	'JUMP <ADDRESS>',$0D,$0A
    DC.B	'MEMory <ADDRESS>',$0D,$0A
    DC.B	'LOAD <SRECORD>',$0D,$0A
    DC.B	'DUMP <START> <END> [<STRING>]',$0D,$0A
    DC.B	'TRAN',$0D,$0A
    DC.B	'NOBR <ADDRESS>',$0D,$0A
    DC.B	'DISP',$0D,$0A
    DC.B	'GO <ADDRESS>',$0D,$0A
    DC.B	'BRGT <ADDRESS>',$0D,$0A
    DC.B	'PLAN',$0D,$0A
    DC.B	'KILL',$0D,$0A
    DC.B	'GB [<ADDRESS>]',$0D,$0A
    DC.B	'REG <REG> <VALUE>',$0D,$0A
    DC.B	'--EXPANSION ROM--',$0D,$0A
    DC.B	'HELP',$0D,$0A
    DC.B    'BASic',$0D,$0A
    DC.B    'CENable',$0D,$0A
    DC.B    'CDISable',$0D,$0A
    DC.B	0,0

sBAS1:
    DC.B    'Loading BASIC ...',$0D,$0A,0,0
sBAS2:
    DC.B    'OK',$0D,$0A,'Verifying BASIC ...',0,0
sBAS3:
    DC.B    'OK. Starting BASIC.',$0D,$0A,0,0
sBASerr:
    DC.B    'Failed.',$0D,$0A,'Unable to run BASIC',$0D,$0A,0,0
sCEN:
    DC.B    'CPU L1 Cache Enabled',$0D,$0A,0,0
sCDIS:
    DC.B    'CPU L1 Cache Disabled',$0D,$0A,0,0


*~Font name~Courier New~
*~Font size~10~
*~Tab type~0~
*~Tab size~4~
