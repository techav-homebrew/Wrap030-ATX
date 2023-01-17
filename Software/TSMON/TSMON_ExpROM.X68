;******************************************************************************
;* Wrap030 TSMON Expansion ROM
;* techav
;* 2021-12-26
;******************************************************************************
;* Provides additional commands for TSMON ROM monitor
;*****************************************************************************/

            INCLUDE "TSMON_Constants.INC"
            INCLUDE "TSMON_FAT.INC"

ROMBASIC:   EQU romSector7  ; address for BASIC in ROM
RAMBASIC:   EQU ramBot+$1000    ; above vector table & TSMON globals
HEAPBASIC:  EQU RAMBASIC+$4000  ; above BASIC program in RAM
SIZBASIC:   EQU $4000       ; total size of BASIC to copy from ROM (~16kB)



;******************************************************************************
; HEADER & INITIALIZATION
;******************************************************************************
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
    callSYS #trapPutString

; Check if FPU installed
    BSR     ucFPUCHK

; Enable L1 cache
    BSR     ucCEnable       ;enable cache by default

; Return to monitor
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
    DC.b    4,4
    DC.b    'CHKD'
    DC.l    ucCHKD
    DC.B    6,4
    dc.B    'SECTOR'
    dc.L    ucSECT
    dc.B    6,3
    dc.B    'FPUCHK'
    dc.L    ucFPUCHK
    dc.B    4,4
    dc.B    'BOOT'
    dc.L    ucBOOT
    DC.B	0,0
;String Constants
sBNR:	DC.B	'ROM2 Loaded.',0,0

    even

;******************************************************************************
; FPU FUNCTIONS
;******************************************************************************
; check for presence of FPU
; RETURNS:
;   D0 - 1: FPU present; 0: FPU not present
fpuCheck:
    move.l  $8,-(SP)        ; save bus error vector
    move.l  $34,-(SP)       ; save coprocessor protocol violation vector
    move.l  #fpuVect,$8     ; load temporary vectors
    move.l  #fpuVect,$8
    move.b  #1,D0           ; set flag
    fnop                    ; test an FPU instruction
    move.l  (SP)+,$34       ; restore vectors
    move.l  (SP)+,$8
    rts                     ; and return
fpuVect:
    move.b  #0,D0           ; clear flag
    rte

ucFPUCHK:
; Check FPU status
    BSR     fpuCheck        ;Check if FPU is installed
    CMP.b   #0,D0           ;Check returned flag
    BNE     .initFPUy       ;
    LEA     sFPUn(PC),A4    ;Get pointer to FPU not installed string
    BRA     .initFPUmsg     ;Jump ahead to print string
.initFPUy:
    LEA     sFPUy(PC),A4    ;Get pointer to FPU installed string
.initFPUmsg:
    callSYS #trapPutString  ;Print FPU status string
    rts

sFPUy:  DC.b    ' FPU Installed.',0,0
sFPUn:  DC.b    ' FPU Not Installed.',0,0

    even

;******************************************************************************
; HELP FUNCTION
;******************************************************************************
; This is our Help function which prints out a list of commands supported by 
; TSMON and this expansion ROM
ucHELP:	
    LEA	    sHELP(PC),A4	;Get pointer to help text string
    callSYS #trapPutString
    RTS

sHELP:	DC.B	'Available Commands:',$0D,$0A
    DC.B	'JUMP <ADDRESS>                 - Run from address',$0D,$0A
    DC.B	'MEMory <ADDRESS>               - Display & Edit memory',$0D,$0A
    DC.B	'LOAD <SRECORD>                 - Load SRecord into memory',$0D,$0A
    DC.B	'DUMP <START> <END> [<STRING>]  - Dump SRecord to aux',$0D,$0A
    DC.B	'TRAN                           - Transparent mode',$0D,$0A
    DC.B	'NOBR <ADDRESS>                 - Remove breakpoint',$0D,$0A
    DC.B	'DISP                           - Print register contents',$0D,$0A
    DC.B	'GO <ADDRESS>                   - Run from address w/Registers',$0D,$0A
    DC.B	'BRGT <ADDRESS>                 - Add breakpoint to table',$0D,$0A
    DC.B	'PLAN                           - Insert breakpoints',$0D,$0A
    DC.B	'KILL                           - Remove breakpoints',$0D,$0A
    DC.B	'GB [<ADDRESS>]                 - Set breakpoints & go',$0D,$0A
    DC.B	'REG <REG> <VALUE>              - Set register contents',$0D,$0A
    DC.B	'--EXPANSION ROM--',$0D,$0A
    DC.B	'HELP                           - Print this message',$0D,$0A
    DC.B    'BASic                          - Load BASIC',$0D,$0A
    DC.B    'CENable                        - Enable L1 cache',$0D,$0A
    DC.B    'CDISable                       - Disable L1 cache',$0D,$0A
    DC.b    'CHKD                           - Check if disk inserted',$0D,$0A
    DC.b    'SECTor <ADDRESS>               - Print disk sector contents',$0D,$0A
    dc.B    'FPUchk                         - Check if FPU is installed',$0D,$0A
    dc.B    'BOOT                           - Execute boot block from disk',$0D,$0A
    DC.B	0,0

    even

;******************************************************************************
; BASIC LOADER
;******************************************************************************
; This function will load BASIC from ROM into RAM and jump to it.
ucLoadBasic:                ; load BASIC into RAM and execute
    MOVEM.L A0-A6/D0-D7,-(A7)   ; save all registers in case we make it back here
    LEA     sBAS1(PC),A4    ; get pointer to header text string
    callSYS #trapPutString
.startCopy:
    LEA     ROMBASIC,A0     ; get pointer to BASIC in ROM
    LEA     RAMBASIC,A1     ; get pointer to RAM above vector table
    MOVE.L  #SIZBASIC>>2,D0 ; number of longwords to copy 
                            ; (NEED BETTER WAY TO GET THIS NUMBER)
.copyLoop:
    MOVE.L  (A0)+,(A1)+     ; copy BASIC into RAM, one Longword at a time
    DBRA    D0,.copyLoop    ; keep copying until finished
    LEA     sBAS2(PC),A4    ; get pointer to verifying string
    callSYS #trapPutString
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
    callSYS #trapPutString
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
    MOVEM.L (A7)+,A0-A6/D0-D7   ; by some miracle we've come back.
    RTS                     ; Restore registers and return

vErrrr:
; BASIC in RAM does not match BASIC in ROM
    LEA     sBASerr(PC),A4  ; get pointer to error string
    callSYS #trapPutString
    MOVEM.L (A7)+,A0-A7/D0-D7   ; restore saved registers
    RTS                     ; and return to TSMON

sBAS1:
    DC.B    'Loading BASIC ... ',0,0
sBAS2:
    DC.B    'OK',$0D,$0A,'Verifying BASIC ... ',0,0
sBAS3:
    DC.B    'OK',$0D,$0A,'Starting BASIC ... ',$0D,$0A,0,0
sBASerr:
    DC.B    'Failed.',$0D,$0A,'Unable to run BASIC',$0D,$0A,0,0

    even

;******************************************************************************
; 68030 CACHE FUNCTIONS
;******************************************************************************
; Enable 68030 cache
ucCEnable:
    MOVEM.L A4/D0,-(A7)     ; save working registers
    MOVE.L  #00000101,D0    ; enable data & instruction cache
    DC.L    $4e7b0002       ; movec D0,CACR
    LEA     sCEN(PC),A4     ; get pointer to feedback string
    callSYS #trapPutString
    MOVEM.L (A7)+,D0/A4     ; restore working registers
    RTS

; Disable 68030 cache
ucCDisable:
    MOVEM.L A4/D0,-(A7)     ; save working registers
    EOR.L   D0,D0           ; disable data & instruction cache
    DC.L    $4e7b0002       ; movec D0,CACR
    LEA     sCDIS(PC),A4    ; get pointer to feedback string
    callSYS #trapPutString
    MOVEM.L (A7)+,D0/A4     ; restore working registers
    RTS

sCEN:
    DC.B    ' CPU L1 Cache Enabled',$0D,$0A,0,0
sCDIS:
    DC.B    ' CPU L1 Cache Disabled',$0D,$0A,0,0

    even

;******************************************************************************
; IDE+FAT DISK FUNCTIONS
;******************************************************************************

; check for disk presence
; RETURNS:
;   D0 - 1: disk present; 0: no disk present
dskChk:
    lea     ideLBAHHRW,A0   ; get LBA HH address
    move.b  #$E0,(A0)       ; set disk to LBA mode
    move.b  (A0),D0         ; read back set value to compare
    cmp.b   #$E0,D0         ; make sure it matches
    bne     .dskChkNo       ; branch if no disk
    move.b  #1,D0           ; return 1 if disk present
    rts                     ; 
.dskChkNo:
    move.b  #0,D0           ; return 0 if no disk present
    rts

; read one sector from disk
; PARAMETERS:
;   A0 - LBA
;   A1 - read buffer
; RETURNS:
;   D0 - 1: success; 0: error
dskRdSect:
    movem.l A0-A2/A4/D1-D3,-(SP)
    bsr     dskChk              ; check if disk present
    cmp.b   #1,D0               ;
    bne     .dskRdErr1          ; jump to error if no disk
    move.l  A0,D0               ; copy provided LBA to D0
    or.l    #$40000000,D0       ; set flag to use LBA addressing
    move.l  #ideBase,A2         ; get base IDE address
    move.b  D0,ideLBALLRW(A2)   ; set LBA LL byte
    lsr.l   #8,D0               ; shift next byte into position
    move.b  D0,ideLBALHRW(A2)   ; set LBA LH byte
    lsr.l   #8,D0               ; shift next byte into position
    move.b  D0,ideLBAHLRW(A2)   ; set LBA HL byte
    lsr.l   #8,D0               ; shift last byte into position
    move.b  D0,ideLBAHHRW(A2)   ; set LBA HH byte & flag
    move.b  #1,ideSectorCountRW(A2) ; tell disk to transfer 1 sector only
    move.b  #ideCmdReadSect,ideCommandWO(A2)    ; send Read Sector command
    move.w  #$FF,D0             ; set loop counter to 256 words
.dskRdLoop:
    moveq   #0,D2               ; clear error counter
.dskRdLp1:
    move.b  ideStatusRO(A2),D1  ; check disk status
    btst    #7,D1               ; check disk busy bit
    beq     .dskRdLp2           ; if clear, go read next word
    addi.b  #1,D2               ; increment error counter
    tst.b   D2                  ; test if error counter has overflowed to 0
    beq     .dskRdErr2          ; jump to error for read timeout
    bra     .dskRdLp1           ; keep looping if we've not timed out yet
.dskRdLp2:
    btst    #0,D1               ; check for read error
    bne     .dskRdErr3          ; if error, then jump to error
    move.w  (A2),D3             ; read word from disk
    lsl.w   #8,D3               ; byte swap to correct wiring error
    move.w  D3,(A1)+            ; save word to disk buffer
    dbra    D0,.dskRdLoop       ; keep looping until all 256 words read
    move.b  #1,D0               ; set read success flag
.dskRdEnd:
    movem.l (A7)+,A0-A2/A4/D1-D3    ; restore working registers
    rts                         ; and return
.dskRdErr1:
    lea     sCHKDn(PC),A4       ; load pointer to no disk error string
    callSYS #trapPutString                 ; print error message
    move.b  #0,D0               ; set error flag
    bra     .dskRdEnd           ; jump to end
.dskRdErr2:
    move.b  #ideCmdNOP,ideCommandWO(A2) ; send disk NOP command
    lea     sDSKRDerr(PC),A4    ; load pointer to disk read error string
    callSYS #trapPutString                 ; print error message
    move.b  #0,D0               ; set error flag
    bra     .dskRdEnd           ; jump to end
.dskRdErr3:
    move.b  D1,D0               ; we have an actual error to look up
    bsr     dskErr              ; jump to disk error handler
    bra     .dskRdEnd           ; jump to end

; check disk error and print helpful message
; PARAMETERS
;   D0 - IDE error register
dskErr:
    btst    #7,D0
    beq     .dskErr6
    lea     sDSKerr7(PC),A4     ; get address of error message
    bra     .dskErrEnd          ; and jump to end
.dskErr6:
    btst    #6,D0
    beq     .dskErr5
    lea     sDSKerr6(PC),A4     ; get address of error message
    bra     .dskErrEnd          ; and jump to end
.dskErr5:
    btst    #5,D0
    beq     .dskErr4
    lea     sDSKerr5(PC),A4     ; get address of error message
    bra     .dskErrEnd          ; and jump to end
.dskErr4:
    btst    #4,D0
    beq     .dskErr3
    lea     sDSKerr4(PC),A4     ; get address of error message
    bra     .dskErrEnd          ; and jump to end
.dskErr3:
    btst    #3,D0
    beq     .dskErr2
    lea     sDSKerr3(PC),A4     ; get address of error message
    bra     .dskErrEnd          ; and jump to end
.dskErr2:
    btst    #2,D0
    beq     .dskErr1
    lea     sDSKerr2(PC),A4     ; get address of error message
    bra     .dskErrEnd          ; and jump to end
.dskErr1:
    btst    #1,D0
    beq     .dskErr0
    lea     sDSKerr1(PC),A4     ; get address of error message
    bra     .dskErrEnd          ; and jump to end
.dskErr0:
    btst    #0,D0
    beq     .dskErrN
    lea     sDSKerr0(PC),A4     ; get address of error message
    bra     .dskErrEnd          ; and jump to end
.dskErrN:
    lea     sDSKRDerr(PC),A4
.dskErrEnd:
    callSYS #trapPutString      ; print selected error message
    rts                         ; and return

sCHKDy	    DC.B	'Disk found.',$0D,$0A,0,0
sCHKDn	    DC.B	'No disk inserted.',$0D,$0A,0,0
sLISTsp	    DC.B	'     ',0,0
sLISThead	DC.B	'File Name        Cluster  File Size',0,0
sINPUTerr	DC.B	'Input error.',$0D,$0A,0,0
sDSKRDerr	DC.B	'Unknown disk read error.',$0D,$0A,0,0

sDSKerr7	DC.B	'Bad block in requested disk sector.',$0D,$0A,0,0
sDSKerr6	DC.B	'Uncorrectable data error in disk.',$0D,$0A,0,0
sDSKerr3
sDSKerr5	DC.B	'Unspecified Removable Media error.',$0D,$0A,0,0
sDSKerr4	DC.B	'Requested disk sector could not be found.',$0D,$0A,0,0
sDSKerr2	DC.B	'Disk command aborted.',$0D,$0A,0,0
sDSKerr1	DC.B	'Disk track 0 not found.',$0D,$0A,0,0
sDSKerr0	DC.B	'Disk data address mark not found.',$0D,$0A,0,0

    even

; user command to check for disk presence
ucCHKD:
    movem.l A0/A4/D0,-(SP)      ; save working registers
    bsr     dskChk              ; check for disk presence
    cmp.b   #0,D0               ; check if disk was found
    bne     .ucCHKD1            ; branch if disk found
    lea     sCHKDn(PC),A4       ; load pointer to no disk found string
    bra     .ucCHKD2            ; jump to end of subroutine
.ucCHKD1:
    lea     sCHKDy(PC),A4       ; load pointer to disk found string
.ucCHKD2:
    callSYS #trapPutString      ; print string
    movem.l (SP)+,A0/A4/D0      ; restore working registers
    rts                         ; and return

; user command to print disk sector contents to console
ucSECT:
    movem.l A0-A1/A4/D0-D3/D7,-(SP) ; save working registers
    callSYS  #trapGetParam      ; system call to fetch parameter 
    tst.b   D7                  ; test for input error
    bne.s   .ucSECTerr1         ; if error, then exit
    move.l  D0,A0               ; A0 points to sector to read
    lea     DATA,A1
    lea     dskBUF(A1),A1       ; A1 points to disk buffer region of memory
    bsr     dskRdSect           ; read selected disk sector
    cmp.b   #1,D0               ; check if sector read was successful
    bne.s   .ucSECTerr2         ; if error, then exit
    move.l  A0,D3               ; get sector number
    clr.B   D2                  ; clear line count
.ucSECT1:
    clr.b   D1                  ; clear word count
    callSYS #trapNewLine        ; system call to print newline
.ucSECT2:
    move.L  D3,D0               ; copy sector to working register
    lsl.L   #1,D0               ; left shift sector by 1 to get base address
    btst    #4,D2               ; check if we're in second half of buffer
    beq     .ucSECT3            ; if no, then skip ahead
    ori.l   #1,D0               ; if second half, then set low bit of base address
.ucSECT3:
    callSYS #trapPutHexLong     ; print base address
    move.b  D2,D0               ; copy line count to working directory
    lsl.B   #4,D0               ; shift by 4 to get low byte of address
    callSYS #trapPutHexByte     ; print low byte of base address
.ucSECT4:
    callSYS #trapPutSpace       ; print a space
    move.w  (A1)+,D0            ; get a word from buffer
    callSYS #trapPutHexWord     ; print word from buffer
    addi.b  #1,D1               ; increment word counter
    cmp.B   #8,D1               ; check for end of line
    bne     .ucSECT4            ; continue line
    addi.B  #1,D2               ; increment line counter
    cmp.B   #$20,D2             ; check for end of buffer
    bne     .ucSECT1            ; start new line
.ucSECTend:
    movem.l (SP)+,A0-A1/A4/D0-D3/D7 ; restore working registers
    rts                         ; and return
.ucSECTerr1:
    lea     sINPUTerr(PC),A4    ; load pointer to input error string
    callSYS #trapPutString      ; and print
    bra     .ucSECTend          ; jump to end
.ucSECTerr2:
    lea     sDSKRDerr(PC),A4    ; load pointer to disk read error string
    callSYS #trapPutString      ; and print
    bra     .ucSECTend          ; jump to end

; load sector 0 from disk and execute if successful
; try to gracefully handle exiting programs that return here
ucBOOT:
    movem.l A0-A1/A4/D0,-(SP)   ; save working registers
    move.l  #0,A0               ; load sector 0
    lea     dskBUF,A1           ; get pointer to disk buffer
    bsr     dskRdSect           ; read sector
    cmp.b   #0,D0               ; check return status
    beq.S   ucBOOTerr1          ; there was a read error
    lea     dskBUF,A1           ; restore that pointer to disk buffer
    move.w  ofsKEY(A1),D0       ; get FAT signature
    cmp.w   #$55AA,D0           ; check FAT signature
    bne.s   ucBOOTerr2          ; unknown disk format error
    pea     ucBOOTret(PC)       ; push return address
    jmp     ofsBTS(A1)          ; jump to bootstrap code
ucBOOTret:
    lea     sBOOTret(PC),A4     ; get pointer to program exit string
ucBOOTend
    callSYS #trapPutString      ; print string
    movem.l (SP)+,A0-A1/A4/D0   ; restore working registers
    rts                         ; return to monitor

ucBOOTerr1:                     ; disk read error
    lea     sDSKRDerr(PC),A4    ; disk read error string
    bra     ucBOOTend           ; print string & exit

ucBOOTerr2:                     ; not a FAT-formatted disk
    lea     sDSKFmtErr(PC),A4   ; disk format error string
    bra     ucBOOTend           ; print string & exit

sDSKFmtErr: dc.b    'Unknown disk format.',$0D,$0A,0,0
sBOOTret:   dc.b    $0D,$0A,$0D,$0A,'Program Exited.',$0D,$0A,0,0

    even

; read one sector from disk
; PARAMETERS:
;   A0 - LBA
;   A1 - read buffer
; RETURNS:
;   D0 - 1: success; 0: error
;dskRdSect:


*~Font name~Courier New~
*~Font size~10~
*~Tab type~0~
*~Tab size~4~
