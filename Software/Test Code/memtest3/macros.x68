;***********************************************************

prntChr    MACRO
chrLp\@
    lea     spioCOM0,A2
    btst    #5,comRegLSR(A2)    ; check if Tx FIFO is empty
    beq.s   chrLp\@             ; loop until empty
    move.b  D0,comRegTX(A2)     ; transmit byte
    ENDM

prntStr    MACRO
prntLp\@    move.b    (A1)+,D0    ;get next byte of string
    cmp.b    #0,D0    ;check for null terminator
    beq.s    prntDn\@    ;if null, exit print loop
    prntChr        ;print Character macro
    bra.s    prntLp\@    ;print next character
prntDn\@    nop        ;end macro
    ENDM

prntStrByName   MACRO
    lea     \1(PC),A1           ; get pointer to named string
    prntStr                     ; and call print string macro
    ENDM

prntNyb     MACRO
    move.l  D0,D2               ;save a copy
    and.b   #$F,D0              ;mask upper nybble
    cmp.b   #9,D0               ;check if letter or number
    bgt.s   nybLtr\@            ;letter
    add.b   #$30,D0             ;add $30 to convert to ASCII number
    bra.s   nybPrnt\@           ;skip to print
nybLtr\@    
    add.b   #$37,D0             ;add $37 to convert to ASCII letter
nybPrnt\@    
    prntChr                     ;print Character macro
    move.l  D2,D0               ;restore copy
    ENDM

prntByte    MACRO
    ROR.b    #4,D0    ;move upper nybble into position
    prntNyb        ;print nybble macro
    ROR.b    #4,D0    ;move lower nybble back into position
    prntNyb        ;print nybble macro
    ENDM

prntWord    MACRO
    move.b    #8,D1    ;set up our rotate length
    ror.w    D1,D0    ;rotate upper byte into position
    prntByte        ;print byte macro
    move.b    #8,D1    ;set up our rotate length
    ror.w    D1,D0    ;rotate upper byte into position
    prntByte        ;print byte macro
    ENDM

prntLWord    MACRO
    swap    D0    ;swap upper word into position
    prntWord        ;print word macro
    swap    D0    ;swap lower word back into position
    prntWord        ;print word macro
    ENDM

prntNewLine MACRO
    move.b  #$0D,D0
    prntChr
    move.b  #$0A,D0
    prntChr
    ENDM

initCOM0    MACRO
    lea     spioCOM0,A2         ; get base address to COM0
    move.b  #$07,comRegFCR(A2)  ; enable COM0 FIFO
;    move.b  #$00,comRegFCR(A1)  ; disable COM0 FIFO, use in char poll mode for testing
    nop
    move.b  #$03,comRegLCR(A2)  ; set COM0 for 8N1
    nop
    move.b  #$00,comRegIER(A2)  ; disable COM0 interrupts
    nop
    move.b  #$83,comRegLCR(A2)  ; enable divisor registers
    nop
    move.b  #$03,comRegDivLo(A2)  ; set divisor low byte (38400)
    nop
    move.b  #$00,comRegDivHi(A2)  ; set divisor high byte (38400)
    nop
    move.b  #$03,comRegLCR(A2)  ; disable divisor registers
    nop
    ENDM

; this macro is just 8 "NOP" statements in a row to clear the bus between 
; memory test pattern writes and reads
nop8        MACRO
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    ENDM