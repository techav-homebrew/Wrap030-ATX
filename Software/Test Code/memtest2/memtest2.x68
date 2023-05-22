romAddr     equ $f0000000
romBot      equ $00000000
ramBot      equ $00000000
;ramTop      equ $01ffffff
; set up program to only test the first 8MB in the first SIMM slot
ramTop      equ $007fffff

stackInit   equ $10000000

romSect0    equ    romBot+$00000
romSect1    equ    romBot+$10000
romSect2    equ    romBot+$20000
romSect3    equ    romBot+$30000
romSect4    equ    romBot+$40000
romSect5    equ    romBot+$50000
romSect6    equ    romBot+$60000
romSect7    equ    romBot+$70000
romTop      equ    romSect7+$ffff

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


initStack    equ    $00000800    ;initial stack pointer at top of first 2k DRAM page

LF    equ    $0A
CR    equ    $0D

;    MEMORY    ROM    romBot,romTop

CODE    EQU    0
DATA    EQU    1
RAM    EQU    2
    
    SECTION    CODE
    org    romSect0

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

;***********************************************************

        ;MC68030 vector table
    dc.l    initStack           ;000 - initial SP
    dc.l    START+romAddr       ;004 - initial PC
    dcb.l   254,intHndlr+romAddr ;245x pointers to generic handler

intHndlr:    
    movem.l D0-D7/A0-A6,-(SP)   ;save all registers
    lea     tblIntTxt(PC),A0    ;get pointer to string table
    move.w  $42(SP),D1          ;get vector offset from stack frame
    andi.l  #$FFF,D1            ;mask out upper word & type from vector offset
    movea.l (A0,D1.w),A1        ;get interrupt string pointer
    prntStr                     ;and print the string
    
    lea        txtPC(PC),A1    
    prntStr
    move.L    $3E(SP),D0
    prntLWord
    
    lea        txtSR(PC),A1
    prntStr
    move.w    $3C,D0
    prntWord
    
    lea       txtA7(PC),A1
    prntStr
    move.l    SP,D0
    sub.l    #$44,D0
    prntLWord
    
    lea       txtA6(PC),A1    
    prntStr
    move.L    $38(SP),D0
    prntLWord
    
    lea       txtA5(PC),A1    
    prntStr
    move.L    $34(SP),D0
    prntLWord
    
    lea       txtA4(PC),A1    
    prntStr
    move.L    $30(SP),D0
    prntLWord
    
    lea       txtA3(PC),A1    
    prntStr
    move.L    $2C(SP),D0
    prntLWord
    
    lea       txtA2(PC),A1    
    prntStr
    move.L    $28(SP),D0
    prntLWord
    
    lea       txtA1(PC),A1    
    prntStr
    move.L    $24(SP),D0
    prntLWord
    
    lea       txtA0(PC),A1    
    prntStr
    move.L    $20(SP),D0
    prntLWord
    
    lea       txtD7(PC),A1    
    prntStr
    move.L    $1C(SP),D0
    prntLWord
    
    lea       txtD6(PC),A1    
    prntStr
    move.L    $18(SP),D0
    prntLWord
    
    lea       txtD5(PC),A1    
    prntStr
    move.L    $14(SP),D0
    prntLWord
    
    lea       txtD4(PC),A1    
    prntStr
    move.L    $10(SP),D0
    prntLWord
    
    lea       txtD3(PC),A1    
    prntStr
    move.L    $0C(SP),D0
    prntLWord
    
    lea       txtD2(PC),A1    
    prntStr
    move.L    $08(SP),D0
    prntLWord
    
    lea       txtD1(PC),A1    
    prntStr
    move.L    $04(SP),D0
    prntLWord
    
    lea       txtD0(PC),A1    
    prntStr
    move.L    $00(SP),D0
    prntLWord
    
    lea       txtTrce(PC),A1
    prntStr
    movea.l    $3E(SP),A3    ;load PC from stack frame
    suba.l    #$10,A3    ;subtract 16 from PC
    moveq.l    #0,D3    ;clear count register
intTrcLp:    move.l    (A3,D3.l),D0    ;get next longword from RAM
    prntLWord        ;print longword as Hex
    lea       txtSpace(PC),A1    ;get pointer to space string
    prntStr        ;and print
    addq.l    #4,D3    ;increment count register
    cmp.l    #$20,D3    ;check for end
    ble    intTrcLp    ;if less than 32, keep looping
    
;    lea       txtStack(PC),A1
;    prntStr
;    movea.l    $44(SP),A3    ;get original stack pointer
;    movea.l    #initStack,A4    ;get start of stack
;intStkLp:    cmp.l    A4,A3    ;see we are at end of stack
;    ble    intStkEnd    ;skip ahead if done
;    move.l    -(A4),D0    ;get next longword from stack
;    prntLWord        ;and print out
;    lea       txtCRLF(PC),A1    ;print newline
;    prntStr
;    bra    intStkLp    ;continue loop
;intStkEnd:    
;    lea       txtEnd(PC),A1
;    prntStr
    
    jmp    START    ;warm reboot
    even
;string storage
txtGeneric:    dc.b    'Generic Interrupt',$D,$A,0
txtBusErr:    dc.b    'Bus Error',$D,$A,0
txtAddrErr:    dc.b    'Address Error',$D,$A,0
txtIllegal:    dc.b    'Illegal Instruction',$D,$A,0
txtZeroDiv:    dc.b    'Divide by Zero',$D,$A,0
txtCHK:    dc.b    'CHK/CHK2 Instruction',$D,$A,0
txtTrapV:    dc.b    'TRAP Instruction',$D,$A,0
txtPriv:    dc.b    'Privilege Violation',$D,$A,0
txtTrace:    dc.b    'Trace',$D,$A,0
txtATrap:    dc.b    'A-Trap Instruction',$D,$A,0
txtFTrap:    dc.b    'F-Trap Instruction',$D,$A,0
txtCprcViol:    dc.b    'Coproc Protocol Err',$D,$A,0
txtFormat:    dc.b    'Format Error',$D,$A,0
txtUninit:    dc.b    'Uninitialized Int',$D,$A,0
txtSpur:    dc.b    'Spurious Interrupt',$D,$A,0
txtInt1:    dc.b    'AVEC Level 1',$D,$A,0
txtInt2:    dc.b    'AVEC Level 2',$D,$A,0
txtInt3:    dc.b    'AVEC Level 3',$D,$A,0
txtInt4:    dc.b    'AVEC Level 4',$D,$A,0
txtInt5:    dc.b    'AVEC Level 5',$D,$A,0
txtInt6:    dc.b    'AVEC Level 6',$D,$A,0
txtInt7:    dc.b    'AVEC Level 7',$D,$A,0
txtTrap0:    dc.b    'Trap 0 Instruction',$D,$A,0
txtTrap1:    dc.b    'Trap 1 Instruction',$D,$A,0
txtTrap2:    dc.b    'Trap 2 Instruction',$D,$A,0
txtTrap3:    dc.b    'Trap 3 Instruction',$D,$A,0
txtTrap4:    dc.b    'Trap 4 Instruction',$D,$A,0
txtTrap5:    dc.b    'Trap 5 Instruction',$D,$A,0
txtTrap6:    dc.b    'Trap 6 Instruction',$D,$A,0
txtTrap7:    dc.b    'Trap 7 Instruction',$D,$A,0
txtTrap8:    dc.b    'Trap 8 Instruction',$D,$A,0
txtTrap9:    dc.b    'Trap 9 Instruction',$D,$A,0
txtTrapA:    dc.b    'Trap A Instruction',$D,$A,0
txtTrapB:    dc.b    'Trap B Instruction',$D,$A,0
txtTrapC:    dc.b    'Trap C Instruction',$D,$A,0
txtTrapD:    dc.b    'Trap D Instruction',$D,$A,0
txtTrapE:    dc.b    'Trap E Instruction',$D,$A,0
txtTrapF:    dc.b    'Trap F Instruction',$D,$A,0
txtFPUunord:    dc.b    'FPU Unordered Cond',$D,$A,0
txtFPUinxct:    dc.b    'FPU Inexact Result',$D,$A,0
txtFPUdiv0:    dc.b    'FPU Divide by Zero',$D,$A,0
txtFPUunder:    dc.b    'FPU Underflow',$D,$A,0
txtFPUoperr:    dc.b    'FPU Operand Error',$D,$A,0
txtFPUover:    dc.b    'FPU Overflow',$D,$A,0
txtFPUnan:    dc.b    'FPU Not a Number',$D,$A,0
txtMMUconfig:    dc.b    'MMU Config Error',$D,$A,0
txt68851:    dc.b    'MC68851 Error',$D,$A,0

txtPC    dc.b    'PC: $',0
txtSR    dc.b    ' SR: $',0
txtA7    dc.b    $D,$A,'A7: $',0
txtA6    dc.b    ' A6: $',0
txtA5    dc.b    ' A5: $',0
txtA4    dc.b    ' A4: $',0
txtA3    dc.b    $D,$A,'A3: $',0
txtA2    dc.b    ' A2: $',0
txtA1    dc.b    ' A1: $',0
txtA0    dc.b    ' A0: $',0
txtD7    dc.b    $D,$A,'D7: $',0
txtD6    dc.b    ' D6: $',0
txtD5    dc.b    ' D5: $',0
txtD4    dc.b    ' D4: $',0
txtD3    dc.b    $D,$A,'D3: $',0
txtD2    dc.b    ' D2: $',0
txtD1    dc.b    ' D1: $',0
txtD0    dc.b    ' D0: $',0
txtTrce    dc.b    $D,$A,'Trace: ',0
txtStack    dc.b    $D,$A,'Stack: ',$D,$A,0
txtEnd    dc.b    $D,$A,'Rebooting ...',$D,$A,0
txtSpace    dc.b    ' ',0
txtCRLF    dc.b    $D,$A,0
    even

;interrupt vector string pointer table
tblIntTxt:    
    dc.l    txtGeneric+romAddr
    dc.l    txtGeneric+romAddr
    dc.l    txtBusErr+romAddr
    dc.l    txtAddrErr+romAddr
    dc.l    txtIllegal+romAddr
    dc.l    txtZeroDiv+romAddr
    dc.l    txtCHK+romAddr
    dc.l    txtTrapV+romAddr
    dc.l    txtPriv+romAddr
    dc.l    txtTrace+romAddr
    dc.l    txtATrap+romAddr
    dc.l    txtFTrap+romAddr
    dc.l    txtGeneric+romAddr
    dc.l    txtCprcViol+romAddr
    dc.l    txtFormat+romAddr
    dc.l    txtUninit+romAddr
    dcb.l    8,txtGeneric+romAddr

    dc.l    txtSpur+romAddr
    dc.l    txtInt1+romAddr
    dc.l    txtInt2+romAddr
    dc.l    txtInt3+romAddr
    dc.l    txtInt4+romAddr
    dc.l    txtInt5+romAddr
    dc.l    txtInt6+romAddr
    dc.l    txtInt7+romAddr
    dc.l    txtTrap0+romAddr
    dc.l    txtTrap1+romAddr
    dc.l    txtTrap2+romAddr
    dc.l    txtTrap3+romAddr
    dc.l    txtTrap4+romAddr
    dc.l    txtTrap5+romAddr
    dc.l    txtTrap6+romAddr
    dc.l    txtTrap7+romAddr
    dc.l    txtTrap8+romAddr
    dc.l    txtTrap9+romAddr
    dc.l    txtTrapA+romAddr
    dc.l    txtTrapB+romAddr
    dc.l    txtTrapC+romAddr
    dc.l    txtTrapD+romAddr
    dc.l    txtTrapE+romAddr
    dc.l    txtTrapF+romAddr
    dc.l    txtFPUunord+romAddr
    dc.l    txtFPUinxct+romAddr
    dc.l    txtFPUdiv0+romAddr
    dc.l    txtFPUunder+romAddr
    dc.l    txtFPUoperr+romAddr
    dc.l    txtFPUover+romAddr
    dc.l    txtFPUnan+romAddr
    dc.l    txtGeneric+romAddr

    dc.l    txtMMUconfig+romAddr
    dcb.l    2,txt68851+romAddr
    dcb.l    197,txtGeneric+romAddr

    even
;***********************************************************
;    org    romSect1
START:            ;now we get on to actual code
    movea.l    #initStack,SP    ;warm boot reset stack pointer

initCOM0:
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
    lea     strCOM0(PC),A1        ; get pointer to string
    prntStr                     ; call print string macro

;******************************************************************************
; MEMORY TEST 1
; This first memory test writes $0000,0000 to every declared memory address,
; starting from the top of memory, then circles back around to make sure each
; address still reads $0000,0000
;

memTest1:
    lea     busCtrlPort,A6
    andi.b  #$fb,(A6)               ; turn off debug LED
    lea     strTestStart(PC),A1     ; gets test start string
    prntStr
    lea     strMemTest1(PC),A1      ; print start of string 1
    prntStr
    moveq.l #0,D5                   ; clear test pattern
;    move.l  #$01FF,D7               ; set high word counter
    move.l  #ramTop>>16,D7           ; set high word counter
    lea     ramTop+1,A0             ; initialize memory pointer
memTest1OuterLp:
    move.l  #$3fff,D6               ; set low word counter
;    lea     strMemT1addr(PC),A1     ; print page string
;    prntStr
;    move.l  D7,D0                   ; get page
;    prntWord                        ; print page number
;    lea     strCRLF(PC),A1          ; print CRLF
;    prntStr
memTest1InnerLp:
    move.l  D5,-(A0)                ; write pattern to memory
    dbra    D6,memTest1InnerLp      ; continue inner loop
    eori.b  #$4,(A6)                ; toggle debug LED
    dbra    D7,memTest1OuterLp      ; continue outer loop
; at this point, we should have cleared all of main memory
; now we need to test and confirm it is all 0
;    move.l  #$01FF,D7               ; set high word counter
    move.l  #ramTop>>16,D7           ; set high word counter
    lea     ramTop+1,A0             ; initialize memory pointer
memTest1OuterLp1:
    move.l  #$3fff,D6               ; set low word counter
;    lea     strMemT1addr1(PC),A1    ; print page string
;    prntStr
;    move.l  D7,D0                   ; get page
;    prntWord                        ; print page number
;    lea     strCRLF(PC),A1          ; print CRLF
;    prntStr
memTest1InnerLp1:
    move.l  -(A0),D4                ; read pattern from memory
    cmp.l   D4,D5                   ; check if it matches
    bne     memTest1err             ; no match, print error
memTest1errRet:
    dbra    D6,memTest1InnerLp1     ; continue inner loop
    eori.b  #$4,(A6)                ; toggle debug LED
    dbra    D7,memTest1OuterLp1     ; continue outer loop
    bra     memTest1done            ; jump to end
memTest1err:
    lea     strMemT1err1(PC),A1     ; print error header string
    prntStr
    move.l  A0,D0                   ; get address
    prntLWord
    lea     strMemT1err2(PC),A1     ; print error mid string 2
    prntStr
    move.l  D4,D0                   ; get bad value
    prntLWord
    lea     strMemT1err3(PC),A1     ; print error mid string 3
    prntStr
    move.l  D5,D0                   ; get test value
    prntLWord
    lea     strCRLF(PC),A1          ; print CRLF
    prntStr
    bra     memTest1errRet          ; keep testing
memTest1done:
    lea     strTest1(PC),A1         ;get address of Test1 Complete string
    prntStr                         ;print Test1 Complete string
    bra     memTest2                ;move on to test2

strMemT1addr:   dc.b    'Writing $0000,0000 to page $',0
strMemT1addr1:  dc.b    'Confirming page $',0
strMemT1err1:   dc.b    'MemTest1 Error at $',0
strMemT1err2:   dc.b    '. Read $',0
strMemT1err3:   dc.b    ', Expected $',0

    even

;******************************************************************************
; MEMORY TEST 2
; This first memory test writes $ffff,ffff to every declared memory address,
; starting from the top of memory, then circles back around to make sure each
; address still reads $ffff,ffff
;

memTest2:
    lea     busCtrlPort,A6
    andi.b  #$fb,(A6)               ; turn off debug LED
    lea     strMemTest2(PC),A1      ; print start of string 1
    prntStr
    move.l  #$ffffffff,D5           ; set test pattern
;    move.l  #$01FF,D7               ; set high word counter
    move.l  #ramTop>>16,D7           ; set high word counter
    lea     ramTop+1,A0             ; initialize memory pointer
memTest2OuterLp:
    move.l  #$3fff,D6               ; set low word counter
;    lea     strMemT2addr(PC),A1     ; print page string
;    prntStr
;    move.l  D7,D0                   ; get page
;    prntWord                        ; print page number
;    lea     strCRLF(PC),A1          ; print CRLF
;    prntStr
memTest2InnerLp:
    move.l  D5,-(A0)                ; write pattern to memory
    dbra    D6,memTest2InnerLp      ; continue inner loop
    eori.b  #$4,(A6)                ; toggle debug LED
    dbra    D7,memTest2OuterLp      ; continue outer loop
; at this point, we should have cleared all of main memory
; now we need to test and confirm it is all 0
;    move.l  #$01FF,D7               ; set high word counter
    move.l  #ramTop>>16,D7           ; set high word counter
    lea     ramTop+1,A0             ; initialize memory pointer
memTest2OuterLp1:
    move.l  #$3fff,D6               ; set low word counter
;    lea     strMemT2addr1(PC),A1    ; print page string
;    prntStr
;    move.l  D7,D0                   ; get page
;    prntWord                        ; print page number
;    lea     strCRLF(PC),A1          ; print CRLF
;    prntStr
memTest2InnerLp1:
    move.l  -(A0),D4                ; read pattern from memory
    cmp.l   D4,D5                   ; check if it matches
    bne     memTest2err             ; no match, print error
memTest2errRet:
    dbra    D6,memTest2InnerLp1     ; continue inner loop
    eori.b  #$4,(A6)                ; toggle debug LED
    dbra    D7,memTest2OuterLp1     ; continue outer loop
    bra     memTest2done            ; jump to end
memTest2err:
    lea     strMemT2err1(PC),A1     ; print error header string
    prntStr
    move.l  A0,D0                   ; get address
    prntLWord
    lea     strMemT2err2(PC),A1     ; print error mid string 2
    prntStr
    move.l  D4,D0                   ; get bad value
    prntLWord
    lea     strMemT2err3(PC),A1     ; print error mid string 3
    prntStr
    move.l  D5,D0                   ; get test value
    prntLWord
    lea     strCRLF(PC),A1          ; print CRLF
    prntStr
    bra     memTest2errRet          ; keep testing
memTest2done:
    lea     strTest2(PC),A1         ;get address of Test1 Complete string
    prntStr                         ;print Test1 Complete string
    bra     memTest3                ;move on to test2

strMemT2addr:   dc.b    'Writing $ffff,ffff to page $',0
strMemT2addr1:  dc.b    'Confirming page $',0
strMemT2err1:   dc.b    'MemTest2 Error at $',0
strMemT2err2:   dc.b    '. Read $',0
strMemT2err3:   dc.b    ', Expected $',0

    even

;******************************************************************************
; MEMORY TEST 3
; Writes $AAAA,AAAA and $5555,5555 to alternating addresses starting at top of
; memory space then reads back to make sure they match
memTest3:
    lea     busCtrlPort,A6
    andi.b  #$fb,(A6)               ; turn off debug LED
    lea     strMemTest3(PC),A1      ; print specific test header
    prntStr

    move.l  #$AAAAAAAA,D5           ; set starting pattern
;    move.l  #$01FF,D7               ; set high word counter
    move.l  #ramTop>>16,D7           ; set high word counter
    lea     ramTop+1,A0             ; intialize memory pointer
memTest3OuterLp:
    move.l  #$3fff,D6               ; set low word counter
;    lea     strMemT3addr(PC),A1     ; print page string
;    prntStr
;    move.l  D7,D0                   ; get page
;    prntWord                        ; print page number
;    lea     strCRLF(PC),A1          ; print CRLF
;    prntStr
memTest3InnerLp:
    move.l  D5,-(A0)                ; write pattern to memory
    eor.l   D5,D5                   ; invert pattern for next write
    dbra    D6,memTest3InnerLp      ; continue inner loop
    eori    #$4,(A6)                ; toggle debug LED
    dbra    D7,memTest3OuterLp      ; continue outer loop
; finished writing patterns, time to confirm
    move.l  #$AAAAAAAA,D5           ; reinitialize starting pattern
;   move.l  #$01FF,D7               ; set high word counter
    move.l  #ramTop>>16,D7           ; set high word counter
    lea     ramTop+1,A0             ; initialize memory pointer
memTest3OuterLp1:
    move.l  #$3fff,D6               ; set low word counter
;    lea     strMemT3addr1(PC),A1    ; print page string
;    prntStr
;    move.l  D7,D0                   ; get page
;    prntWord                        ; print page number
;    lea     strCRLF(PC),A1          ; print CRLF
;    prntStr
memTest3InnerLp1:
    move.l  -(A0),D4                ; read pattern from memory
    cmp.l   D4,D5                   ; check if it matches
    bne     memTest3err             ; no match, print error
memTest3errRet:
    eor.l   D5,D5                   ; invert pattern for next read
    dbra    D6,memTest3InnerLp1     ; continue inner loop
    eori.b  #$4,(A6)                ; toggle debug LED
    dbra    D7,memTest3OuterLp1     ; continue outer loop
    bra     memTest3done            ; jump to end
memTest3err:
    lea     strMemT3err1(PC),A1     ; print error header string
    prntStr
    move.l  A0,D0                   ; get address
    prntLWord
    lea     strMemT3err2(PC),A1     ; print error mid string 2
    prntStr 
    move.l  D4,D0                   ; get bad value
    prntLWord
    lea     strMemT3err3(PC),A1     ; print error mid string 3
    prntStr
    move.l  D5,D0                   ; get test value
    prntLWord
    lea     strCRLF(PC),A1          ; print CRLF
    prntStr
    bra     memTest3errRet          ; keep testing
memTest3done:
    lea     strTest3(PC),A1         ; get address of Test3 complete string
    prntStr                         ; print Test3 Complete string
    bra     memTest4                ; move on to test3

strMemT3addr:   dc.b    'Writing pattern to page $',0
strMemT3addr1:  dc.b    'Confirming page $',0
strMemT3err1:   dc.b    'MemTest3 Error at $',0
strMemT3err2:   dc.b    '. Read $',0
strMemT3err3:   dc.b    ', Expected $',0

    even

;******************************************************************************
; MEMORY TEST 4
; Writes byte pattern $55, $AA, $11, $88 to memory starting at bottom of RAM
; then reads back as long words starting from top of RAM, overwriting with
; byte pattern $33, $CC, $66, $99
;
memTest4:
    eori.b  #$4,(A6)                ; toggle debug LED
    lea     strMemTest4(PC),A1      ; print specific test header
    prntStr
    movea.l #ramBot,A0              ; start by clearing memory
    eor.l   D0,D0                   ; use D0 to clear memory
memTest4a:
    eori.b  #$4,(A6)                ; toggle debug LED
    move.l  D0,(A0)+                ; clear next memory address
    cmpa.l  #ramTop,A0              ; are we at top of memory yet?
    blt     memTest4a               ; if not, then keep clearing

    lea     ramBot,A0               ; start test at base of RAM
memTest4b:
    move.b  #$55,(A0)+              ; write test pattern bytes
    move.b  #$AA,(A0)+              ;
    move.b  #$11,(A0)+              ;
    move.b  #$88,(A0)+              ;
    eori    #$4,(A6)                ; toggle debug LED
    cmpa.l  #ramTop,A0              ; are we at top of memory yet?
    blt     memTest4b               ; if not, then keep writing test pattern

    lea     strMemT4p1(PC),A1       ; print status update
    prntStr
    lea     ramBot,A0               ; set up base address for confirmation & next pattern write
memTest4c:
    move.l  (A0),D7                 ; check pattern at current address
    cmp.l   #$55AA1188,D7           ; does pattern 1 match?
    bne     memTest4err1            ; if no match, then jump to error
memTest4err1ret:
    move.b  #$33,(A0)+              ; now swap things around and write the pattern again
    move.b  #$CC,(A0)+              ;
    move.b  #$66,(A0)+              ;
    move.b  #$99,(A0)+              ;
    eori.b  #$4,(A6)                ; toggle debug LED
    cmpa.l  #ramTop,A0              ; are we at top of memory yet?
    blt     memTest4c               ; if not, then keep checking & writing patterns

    lea     strMemT4p2(PC),A1       ; print status update
    prntStr
    lea     ramTop+1,A0             ; this time, we'll check from the top down
memTest4d:
    eori.b  #$4,(A6)                ; toggle debug LED
    move.l  -(A0),D7                ; check pattern at current address
    cmp.l   #$33CC6699,D7           ; does pattern 2 match?
    bne     memTest4err2            ; if no match, then jump to error
memTest4err2ret:
    cmpa.l  #ramBot+4,A0            ; are we at bottom of memory yet?
    bgt     memTest4d               ; if not, then continue testing
    bra     memTest4end             ; jump to end of test

memTest4err1:                       ; print phase 1 error
    movea.l A0,A6                   ; save address where error occurred
    lea     strMemT4err1a(PC),A1    ; print error header
    prntStr                         ;
    move.l  A6,D0                   ; get error address
    prntLWord                       ; and print it
    lea     strMemT4err3(PC),A1     ; print "Expected" string
    prntStr                         ;
    move.l  #$55AA1188,D0           ; load expected value
    prntLWord                       ; and print it
    lea     strMemT4err4(PC),A1     ; print "Read" string
    prntStr
    move.l  D7,D0                   ; get read value
    prntLWord                       ; and print it
    lea     strCRLF(PC),A1          ; print newline
    prntStr
    movea.l A6,A0                   ; restore test address
    bra     memTest4err1ret         ; and return to testing

memTest4err2:                       ; print phase 2 error
    movea.l A0,A6                   ; save address where error occurred
    lea     strMemT4err2a(PC),A1    ; print error header
    prntStr                         ;
    move.l  A6,D0                   ; get error address
    prntLWord                       ; and print it
    lea     strMemT4err3(PC),A1     ; print "Expected" string
    prntStr
    move.l  #$33CC6699,D0           ; load expected value
    prntLWord                       ; and print it
    lea     strMemT4err4(PC),A1     ; print "Read" string
    prntStr
    move.l  D7,D0                   ; get read value
    prntLWord                       ; and print it
    lea     strCRLF(PC),A1          ; print newline
    prntStr
    movea.l A6,A0                   ; restore test address
    bra     memTest4err2ret         ; and return to testing

memTest4end:
    lea     strTest4(PC),A1         ; get test complete string
    prntStr                         ; and print it
    bra     memTest5                ; jump to next test

strMemT4err1a:  dc.b    'Mem Test 4p1 error at $',0
strMemT4err2a:  dc.b    'Mem Test 4p2 error at $',0
strMemT4err3:   dc.b    '. Expected: $',0
strMemT4err4:   dc.b    ', Read: $',0
strMemT4p1:     dc.b    'Mem Test 4 p1 write complete.'
strMemT4p2:     dc.b    'Mem Test 4 p1 verify & p2 write complete.'
    even

;******************************************************************************
; MEMORY TEST 5
; Incrementing addresses
;
memTest5:
    lea     strMemTest5(PC),A1      ;print specific test header
    prntStr
    movea.l #ramBot,A0            ;get starting address
memTest5a:  
    move.l  A0,D0                ;write address as pattern
    move.l  D0,(A0)+            ;write address as pattern
    cmpa.l  #ramTop,A0        ;check for top of RAM
    blt     memTest5a            ;continue loop
    movea.l #ramBot,A0            ;get starting address
memTest5b:    
    move.l  A0,D6                ;copy address as pattern
    move.l  (A0)+,D7            ;read stored value
    cmp.l   D6,D7                ;compare value with pattern
    bne     memTest5err1        ;jump to error handler
memTest5err1ret:
    cmpa.l  #ramTop,A0        ;check for end of loop
    blt     memTest5b            ;continue loop
    bra     memTest5end            ;jump to end

memTest5err1:
    movea.l A0,A6                ;save address
    lea     strErr5a0(PC),A1        ;get error string header
    prntStr                    ;and print
    move.l  A6,D0                ;get failed RAM address
    prntLWord                    ;and print
    lea     strErr3a1(PC),A1        ;get error string middle
    prntStr                    ;and print
    move.l  D6,D0                ;get pattern value
    prntLWord                    ;and print
    lea     strErr3a2(PC),A1        ;get error string end
    prntStr                    ;and print
    move.l  D7,D0                ;get read value
    prntLWord                    ;and print
    lea     strCRLF(PC),A1            ;get newline
    prntStr                    ;and print
    movea.l A6,A0                ;restore address
    bra     memTest5err1ret        ;continue test
    
memTest5end:
    lea     strTest5(PC),A1        ;get test end string
    prntStr                    ;and print

;******************************************************************************
; MEMORY TEST 6
; Mis-aligned longwords
;    
memTest6:
    lea     strMemTest6(PC),A1      ;print specific test header
    prntStr
    movea.l #ramBot,A0            ;get base address
memTest6a:  
    move.b  #$01,(A0)+            ;write byte
    move.l  #$02040810,(A0)+        ;write mis-aligned longword
    move.b  #$7E,(A0)+            ;write byte
    move.l  #$204080FD,(A0)+        ;write mis-aligned longword
    move.b  #$10,(A0)+            ;write byte
    move.l  #$FBF7EFDF,(A0)+        ;write mis-aligned longword
    move.b  #$E7,(A0)+            ;write final pattern byte
    cmpa.l  #ramTop-16,A0        ;check for end
    blt     memTest6a            ;continue loop
    movea.l #ramBot,A0            ;get base address for check
memTest6b:  
    move.l  #$01020408,D6        ;get check pattern
    move.l  (A0)+,D7            ;read test value
    cmp.l   D6,D7                ;check read value
    bne     memTest6err1        ;jump if error
memTest6err1ret:
    move.l  #$107E2040,D6        ;get check pattern
    move.l  (A0)+,D7            ;read test value
    cmp.l   D6,D7                ;check read value
    bne     memTest6err2        ;jump if error
memTest6err2ret
    move.l  #$80FD10FB,D6        ;get check pattern
    move.l  (A0)+,D7            ;read test value
    cmp.l   D6,D7                ;check read value
    bne     memTest6err3        ;jump if error
memTest6err3ret:
    move.l  #$F7EFDFE7,D6        ;get check pattern
    move.l  (A0)+,D7            ;read test value
    cmp.l   D6,D7                ;check read value
    bne     memTest6err4        ;jump if error
memTest6err4ret:
    cmpa.l  #ramTop-16,A0        ;check for end
    blt     memTest6b            ;continue loop
    bra     memTest6end            ;jump to end
    
memTest6err1:
    moveq   #1,D5                ;error code 1
    bra     memTest6errAll        ;jump to error handler
memTest6err2:
    moveq   #2,D5                ;error code 2
    bra     memTest6errAll        ;jump to error handler
memTest6err3:
    moveq   #3,D5                ;error code 3
    bra     memTest6errAll        ;jump to error handler
memTest6err4:
    moveq   #4,D5                ;error code 4
memTest6errAll:
    move.l  A0,A6                ;save address
    lea     strErr6a0(PC),A1        ;get error string header
    prntStr                    ;and print
    move.l  A6,D0                ;get failed RAM address
    sub.l   #4,D0                ;subtract 4 since it was already incremented
    prntLWord                    ;and print
    lea     strErr3a1(PC),A1        ;get error string middle
    prntStr                    ;and print
    move.l  D6,D0                ;get pattern value
    prntLWord                    ;and print
    lea     strErr3a2(PC),A1        ;get error string end
    prntStr
    move.l  D7,D0                ;get read value
    prntLWord                    ;and print
    lea     strCRLF(PC),A1            ;get newline
    prntStr                    ;and print
    move.l  A6,A0                ;restore address
    cmp.b   #1,D5                ;check error code 1
    beq     memTest6err1ret        ;continue test 1
    cmp.b   #2,D5                ;check error code 2
    beq     memTest6err2ret        ;continue test 2
    cmp.b   #3,D5                ;check error code 3
    beq     memTest6err3ret        ;continue test 3
    bra     memTest6err1ret        ;continue test 4

memTest6end:
    lea     strTest6(PC),A1        ;get test end string
    prntStr                    ;and print
    
    jmp     memTest1            ;long jump back to start
    

;***********************************************************

strCOM0     dc.b    $0D,$0A,'COM0 Ready',$0D,$0A,0
strBasCpy1: dc.b    'Loading Basic...',$0D,$0A,0
strBasCpy2: dc.b    'Loaded. Verifying...',$0D,$0A,0
strBasCpy3: dc.b    'Load success. Starting...',$0D,$0A,0
strBasCpy4: dc.b    'Verify failed at $',0
strBasCpy5: dc.b    '. ROM: $',0
strBasCpy6: dc.b    ', RAM: $',0
strCRLF     dc.b    CR,LF,0
strTestStart: dc.b  'Starting memory tests',CR,LF,0
strTest1:   dc.b    'Mem Test 1 Complete',$0D,$0A,0
strTest2:   dc.b    'Mem Test 2 Complete',$0D,$0A,0
strTest3:   dc.b    'Mem Test 3 Complete',CR,LF,0
strTest4:   dc.b    'Mem Test 4 Complete',CR,LF,0
strTest5:   dc.b    'Mem Test 5 Complete',CR,LF,0
strTest6:   dc.b    'Mem Test 6 Complete',CR,LF,0
strErr1:    dc.b    'Mem Test 1 error at $',0
strErr2:    dc.b    'Mem Test 2 error at $',0
strErr1a:   dc.b    '. Expected: $00000000, Read: $',0
strErr2a    dc.b    '. Expected: $ffffffff, Read: $',0
strErr3a0   dc.b    'Mem Test 3 error at $',0
strErr3a1   dc.b    '. Expected: $',0
strErr3a2   dc.b    ', Read: $',0
;strErr4a0   dc.b    'Mem Test 4 error at $',0
;strErr4a1   dc.b    '. Expected: $AA55AA55, Read: $',0
;strErr4a2   dc.b    '. Expected: $55AA55AA, Read: $',0
strErr5a0   dc.b    'Mem Test 5 error at $',0
strErr6a0   dc.b    'Mem Test 6 error at $',0

strMemTest1 dc.b    'Starting test 1 (Longword $0000,0000) ',CR,LF,0
strMemTest2 dc.b    'Starting test 2 (Longword $FFFF,FFFF)',CR,LF,0
strMemTest3 dc.b    'Starting test 3 (Longword $AAAA,AAAA & $5555,5555)',CR,LF,0
strMemTest4 dc.b    'Starting test 4 (Byte pattern $55,$AA,$11,$88 followed by $33,$CC,$66,$99)',CR,LF,0
strMemTest5 dc.b    'Starting test 5 (Incrementing Addresses)',CR,LF,0
strMemTest6 dc.b    'Starting test 6 (Mis-aligned Longwords)',CR,LF,0
strMemTest7 dc.b    'Starting test 7',CR,LF,0
strMemTest8 dc.b    'Starting test 8',CR,LF,0

    END    START
