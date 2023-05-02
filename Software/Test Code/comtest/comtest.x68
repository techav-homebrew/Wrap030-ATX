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


; macros
prntChr	MACRO
;chrLp\@
;    btst    #5,comRegLSR(A1)    ; check if Tx FIFO is empty
;    beq.s   chrLp\@             ; loop until empty
    move.b  D0,comRegTX(A1)     ; transmit byte
    nop
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



; initial vector table
	ORG	0
VECTOR:
    dc.l    stackInit           ; initial SP
    dc.l    START               ; initial PC
;    dcb.l   245,romBot+START    ; fill out vector table

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

MAINLOOP:
    eor.b   #$04,(A0)           ; invert debug LED
    lea     strHello,A4         ; get pointer to string
    prntStr                     ; print string macro

comRxTest:
    btst    #0,comRegLSR(A1)    ; check for received byte
    beq.s   comRxTest           ; loop until byte received
    move.b  comRegRX(A1),D0     ; fetch received byte (& ignore)
    bra.s   MAINLOOP            ; continue main program loop


strHello:
    dc.b    "HELLORLD",$0A,$0B,0