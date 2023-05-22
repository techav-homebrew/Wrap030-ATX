; test the WD16C552 com ports
; these are 16c550 compatible serial ports

; Memory addressing
romBot      equ $f0000000
ramBot      equ $00000000
ramTop      equ ramBot + $0fffffff
stackInit   equ $10000000

; Bus Controller Register
busCtrlPort equ $e0000000

; SPIO addressing
spioPort    equ $dc000000
; CPU A[5:3] wired to SPIO A[2:0]
; CPU A[7:6] select SPIO devices:
;   00 - COM0
;   01 - COM1
;   02 - LPT0
;   03 - Not used
spioCOM0    equ spioPort + $00
spioCOM1    equ spioPort + $40
spioLPT0    equ spioPort + $80

; COM Port Addresses
comRegRX    equ (0*8)  ; Receive Buffer Register (read only) (Requires LCR DLAB clear)
comRegTX    equ (0*8)  ; Transmit Holding Register (write only) (Requires LCR DLAB clear)
comRegIER   equ (1*8)  ; Interrupt Enable Register
comRegIIR   equ (2*8)  ; Interrupt Identification Register (read only)
comRegFCR   equ (2*8)  ; FIFO Control Register (write only)
comRegLCR   equ (3*8)  ; Line Control Register
comRegMCR   equ (4*8)  ; Modem Control Register
comRegLSR   equ (5*8)  ; Line Status Register
comRegMSR   equ (6*8)  ; Modem Status Register
comRegSPR   equ (7*8)  ; Scratch Pad Register
comRegDivLo equ (0*8)  ; Divisor Latch Register LSB (Requires LCR DLAB set)
comRegDivHi equ (1*8)  ; Divisor Latch Register MSB (Requires LCR DLAB set)

; COM baud divisor table (@ 1.8432MHz)
comBaud96k  equ 12  ;   9600
comBaud38k  equ  3  ;  38400
comBaud56k  equ  2  ;  56000
comBaud115k equ  1  ; 115200

;******************************************************************************
; macros
prntChr	MACRO
chrLp\@
    btst    #5,comRegLSR(A1)    ; check if Tx FIFO is empty
    beq.s   chrLp\@             ; loop until empty
    move.b  D0,comRegTX(A1)     ; transmit byte
    ENDM

prntStr	MACRO
prntLp\@
	move.b	(A4)+,D0	; get next byte of string
	cmp.b	#0,D0	; check for null terminator
	beq.s	prntDn\@	; if null, exit print loop
	prntChr		; call print character macro
	bra.s	prntLp\@	; continue loop and print next character
prntDn\@
	nop		; end macro
	ENDM

prntFail    MACRO
    lea     strFailed,A4
    prntStr
    ENDM

prntOK      MACRO
    lea     strOK,A4
    prntStr
    ENDM

prntNyb     MACRO
    move.l  D0,D2               ; save a copy
    and.b   #$F,D0              ; mask upper nybble
    cmp.b   #9,D0               ; check if letter or number
    bgt.s   nybLtr\@            ; letter
    add.b   #$30,D0             ; add $30 to convert to ASCII number
    bra.s   nybPrnt\@           ; skip ahead to print
nybLtr\@
    add.b   #$37,D0             ; add $37 to conver to ASCII letter
nybPrnt\@
    prntChr                     ; call printChr macro
    move.l  D2,D0               ; restore copy
    ENDM

prntByte    MACRO
    ROR.b   #4,D0               ; move upper nybble into position
    prntNyb                     ; print upper nybble
    ROR.b   #4,D0               ; move lower nybble into position
    prntNyb                     ; print lower nybble
    ENDM

prntWord    MACRO
    move.b  #8,D1               ; set up rotate length
    ror.w   D1,D0               ; rotate upper byte into position
    prntByte                    ; print upper byte
    move.b  #8,D1               ; set up rotate length again
    ror.w   D1,D0               ; rotate lower byte into position
    prntByte                    ; print loewr byte
    ENDM

prntLong    MACRO
    swap    D0                  ; swap upper word into position
    prntWord                    ; print upper word
    swap    D0                  ; swap lower word into position
    prntWord                    ; print lower word
    ENDM

prntNewline MACRO
    move.b  #$0d,D0             ; carriage return
    prntChr
    move.b  #$0a,D0             ; line feed
    prntChr
    ENDM

; initial vector table
	ORG	0
VECTOR:
    dc.l    stackInit           ; initial SP
    dc.l    START+romBot        ; initial PC
    dc.l    vecBERR             ; bus error vector
    dc.l    vecADER             ; address error vector
    dcb.l   243,romBot+START    ; fill out vector table

; initial program
START:
    lea     busCtrlPort,A0      ; get address to bus controller register
    ori.b   #$04,(A0)           ; turn on debug LED

initCOM0:
    lea     spioCOM0,A1         ; get base address to COM0
    move.b  #$07,comRegFCR(A1)  ; enable COM0 FIFO
;    move.b  #$00,comRegFCR(A1)  ; disable COM0 FIFO, use in char poll mode for testing
    nop
    move.b  #$03,comRegLCR(A1)  ; set COM0 for 8N1
    nop
    move.b  #$00,comRegIER(A1)  ; disable COM0 interrupts
    nop
    move.b  #$83,comRegLCR(A1)  ; enable divisor registers
    nop
    move.b  #$03,comRegDivLo(A1)  ; set divisor low byte (38400)
    nop
    move.b  #$00,comRegDivHi(A1)  ; set divisor high byte (38400)
    nop
    move.b  #$03,comRegLCR(A1)  ; disable divisor registers
    nop
    lea     strHello(PC),A4        ; get pointer to string
    prntStr                     ; call print string macro

initRAM:
    lea     strRamInit(PC),A4   ; get ram init header string
    prntStr                     ; and print it
    move.w  #$400,D0            ; delay to let DRAM controller initialize
.ramDelayLp:
    dbra    D0,.ramDelayLp      ; keep delaying
    lea     strOK(PC),A4        ; print memory initialization ok string
    prntStr

; test if overlay is properly disabled
    move.l  #$a5a5a5a5,D0       ; set test pattern 
    move.l  D0,ramBot           ; write to bottom of RAM
    move.l  ramBot,D1           ; read result
    cmp.l   D1,D0               ; and compare
    bne     overlayTestFail     ; fail
    lea     strOvrlOk(PC),A4    ; get test passed string
    prntStr                     ; and print

    lea     4+ramBot,A0         ; get test address
    move.l  #0,(A0)             ; clear it
    move.b  #$a1,0(A0)          ; write test pattern
    move.b  #$52,1(A0)
    move.b  #$3a,2(A0)
    move.b  #$45,3(A0)
    move.l  (A0),D1             ; read back result
    move.l  #$a1523a45,D0       ; get test comparison
    cmp.l   D1,D0               ; check if they match
    bne     ramWriteTestFail    ; nope
    lea     strRamWrOK(PC),A4   ; get test passed string
    prntStr


MAINLOOP:
    lea     busCtrlPort,A0      ; get address to bus controller register
    eor.b   #$04,(A0)           ; invert debug LED
    move.w  #$7fff,D0           ; initialize loop
delayLoop:
    dbra    D0,delayLoop
    bra     MAINLOOP

overlayTestFail:
    lea     strOvrlFail(PC),A4  ; get string
    prntStr                     ; and print
    bra     MAINLOOP

ramWriteTestFail:
    lea     strRamWrFail(PC),A4 ; get error string
    prntStr                     ; and print
    bra     MAINLOOP

vecBERR:
    lea     strBERR,A4
    bra     vectorPrint

vecADER:
    lea     strADER,A4
    bra     vectorPrint

vectorPrint:
    prntStr
    bra     MAINLOOP
    move.w  #$1000,D0
.vecLp:
    dbra    D0,.vecLp
    bra     MAINLOOP

strHello:   dc.b    $0d,$0a,"COM0 Init Complete.",$0d,$0a,0
strBERR:    dc.b    "Bus Error",$0d,$0a,0
strADER:    dc.b    "Address Error",$0d,$0a,0
strRamInit: dc.b    "Waiting for memory to initialize ... ",0
strOK:      dc.b    "OK.",$0d,$0a,0
strOvrlFail: dc.b   "Disable Overlay test failed.",$0d,$0a,0
strOvrlOk:  dc.b    "Disable Overlay test passed.",$0d,$0a,0
strRamWrFail: dc.b  "RAM Byte Write test failed.",$0d,$0a,0
strRamWrOK: dc.b    "RAM Byte Write test passed.",$0d,$0a,0
strOverlayDis: dc.b "Disabling Overlay ... ",0

strRamPgSizChk:
            dc.b    "Checking RAM hardware page size ... ",0
strRamPg2k: dc.b    "2kB",$0d,$0a,0
strRamPg4k: dc.b    "4kB",$0d,$0a,0
strRamPg8k: dc.b    "8kB",$0d,$0a,0
strRamPg16: dc.b    "16kB",$0d,$0a,0