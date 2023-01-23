
width:      equ 160
height:     equ 200
vidAddr:    equ $80800000
initI1:     fequ.s  -1.0
initI2:     fequ.s   1.0
initR1:     fequ.s  -2.0
initR2:     fequ.s   1.0

; Generic macro for system calls
    MACRO callSYS
    movem.l A0-A1/D0-D1,-(SP)   ; save working registers
    move.b  \1,D1               ; load syscall number
    trap    #0                  ; call syscall handler
    movem.l (SP)+,A0-A1/D0-D1   ; restore working registers
    ENDM

    MACRO callPBYTE
    movem.l A0-A1/D0-D1,-(SP)   ; save working registers
    move.b  \1,D0               ; load word to print
    move.b  #sysPBYTE,D1        ; load syscall number
    trap    #0                  ; call syscall handler
    callSYS #sysPSPACE          ; follow with a space
    movem.l (SP)+,A0-A1/D0-D1   ; restore working registers
    ENDM

    MACRO callPWORD
    movem.l A0-A1/D0-D1,-(SP)   ; save working registers
    move.w  \1,D0               ; load word to print
    move.b  #sysPWORD,D1        ; load syscall number
    trap    #0                  ; call syscall handler
    callSYS #sysPSPACE          ; follow with a space
    movem.l (SP)+,A0-A1/D0-D1   ; restore working registers
    ENDM

    MACRO callPLONG
    movem.l A0-A1/D0-D1,-(SP)   ; save working registers
    move.l  \1,D0               ; load word to print
    move.b  #sysPLONG,D1        ; load syscall number
    trap    #0                  ; call syscall handler
    callSYS #sysPSPACE          ; follow with a space
    movem.l (SP)+,A0-A1/D0-D1   ; restore working registers
    ENDM

    MACRO callPFLOAT
    movem.l A0-A1/D0-D1,-(SP)   ; save working registers
    move.l  \1(A1),D0           ; load fload to print
    move.b  #sysPLONG,D1        ; load syscall number
    trap    #0                  ; call syscall handler
    callSYS #sysPSPACE          ; follow with a space
    movem.l (SP)+,A0-A1/D0-D1   ; restore working registers
    ENDM

sysGETCHAR  equ 0
sysPUTCHAR  equ 1
sysNEWLINE  equ 2
sysPSTRING  equ 4
sysPBYTE    equ 9
sysPWORD    equ 10
sysPLONG    equ 11
sysPSPACE   equ 12

    org     $00004000
start:
    movem.l A0-A6/D0-D7,-(SP)   ; save all registers to start
    lea     sHead(PC),A4    ; get pointer to header string
    callSYS #sysPSTRING     ; and print it

; 6 POKE $8080FFFF,$00
    lea     vidAddr,A0      ; get base address to video card
    move.l  #$0FFFF,D0      ; get offset to settings register
    move.b  #0,0(A0,D0.l)   ; apply settings to video card
    move.l  #$7fff,D0       ; set up loop counter
    eor.l   D1,D1           ; clear D1 to quickly clear VRAM with
clearVram:
    move.b  D1,0(A0,D0.L)   ; clear each VRAM address
    move.b  D1,0(A0,D0.L)   ; do it now
    dbra    D0,clearVram    ; loop until all VRAM cleared
    
    lea     vars(PC),A1     ; get pointer to variables region

; 10 X1=159:Y1=199
    move.w  #width-1,D0     ; D0=X1
    fmove.w D0,FP0
    fmove.s FP0,X1(A1)
    move.w  #height-1,D1    ; D1=Y1
    fmove.w D1,FP0
    fmove.s FP0,Y1(A1)

; 20 I1=-1.0:I2=1.0:R1=-2.0:R2=1.0
    ; I1=-1.0
    fmove.s #initI1,FP0     ; FP0=I1
    fmove.s FP0,I1(A1)
    ; I2=1.0
    fmove.s #initI2,FP0     ; FP0=I2
    fmove.s FP0,I2(A1)
    ; R1=-2.0
    fmove.s #initR1,FP0     ; FP0=R1
    fmove.s FP0,R1(A1)
    ; R2=1.0
    fmove.s #initR2,FP0     ; FP0=R2
    fmove.s FP0,R2(A1)

; 30 S1=(R2-R1)/X1:S2=(I2-I1)/Y1
    ; S1=(R2-R1)/X1
    fmove.s R2(A1),FP0      ; FP0=R2
    fsub.s  R1(A1),FP0      ; FP0=FP0-R1=R2-R1
    fdiv.s   X1(A1),FP0  ; FP0=FP0/X1=(R2-R1)/X1
    fmove.s FP0,S1(A1)      ; S1=FP0
    ; S2=(I2-I1)/Y1
    fmove.s I2(A1),FP0      ; FP0=I2
    fsub.s  I1(A1),FP0      ; FP0=FP0-I1=I2-I1
    fdiv.s   Y1(A1),FP0  ; FP0=FP0/Y1=(I2-I1)/Y1
    fmove.s FP0,S2(A1)      ; S2=FP0

    lea     sInit(PC),A4    ; get pointer to init complete string
    callSYS #sysPSTRING     ; and print it

; 40 FOR Y=0 TO Y1 STEP 2
    move.w  #0,D3           ; Y=0
nextY:

; 50 I3=I1+S2*Y
    fmove.w D3,FP0          ; FP0=Y
    fmul.s  S2(A1),FP0      ; FP0=FP0*S2=Y*S2
    fadd.s  I1(A1),FP0      ; FP0=FP0+I1=(Y*S2)+I1
    fmove.s FP0,I3(A1)      ; I3=FP0

; 60 FOR X=0 TO X1
    move.w  #0,D2           ; X=0
nextX:

; 70 R3=R1+S1*X:Z1=R3:Z2=I3
    ; R3=R1+S1*X
    fmove.w D2,FP0          ; FP0=X
    fmul.s  S1(A1),FP0      ; FP0=FP0*S1=X*S1
    fadd.s  R1(A1),FP0      ; FP0=FP0+R1=(X*S1)+R1
    fmove.s FP0,R3(A1)      ; R3=FP0
    ; Z1=R3
    fmove.s FP0,Z1(A1)      ; Z1=FP0
    ; Z2=I3
    move.l  I3(A1),Z2(A1)   ; Z2=I3
    ;fmove.s I3(A1),FP0      ; FP0=I3
    ;fmove.s FP0,Z2(A1)      ; Z2=FP0=I3

; 80 FOR N=0 TO 15
    move.w  #0,D4           ; N=0
nextN:
    ; lea     sNextN(PC),A4
    ; callSYS #sysPSTRING
    ; callSYS #sysNEWLINE
    ; callPFLOAT  Z1
    ; callPFLOAT  Z2
    ; callPFLOAT  vA
    ; callPFLOAT  vB
    ; callPFLOAT  I3
    ; callPFLOAT  R3
    ; callSYS #sysNEWLINE
; 90 A=Z1*Z1:B=Z2*Z2
    ; A=Z1*Z1
    fmove.s Z1(A1),FP0      ; FP0=Z1
    fmul.x  FP0,FP0         ; FP0=FP0*FP0=Z1*Z1
    fmove.s FP0,vA(A1)      ; A=FP0
    ; B=Z2*Z2
    fmove.s Z2(A1),FP0      ; FP0=Z2
    fmul.x  FP0,FP0         ; FP0=FP0*FP0=Z2*Z2
    fmove.s FP0,vB(A1)      ; B=FP0

; 100 IF A+B>4.0 THEN GOTO 130
    fmove.s vA(A1),FP0      ; FP0=A
    fadd.s  vB(A1),FP0      ; FP0=FP0+B=A+B
    fcmp.s  #4.0,FP0        ; [FLAGS]=FP0-4.0
    fbgt    drawPixel       ; if FP0>4.0, skip to drawPixel

; 110 Z2=2*Z1*Z2+I3:Z1=A-B+R3
    ; Z2=2*Z1*Z2+I3
    fmove.s Z1(A1),FP0      ; FP0=Z1
    fmul.s  #2.0,FP0        ; FP0=2.0*Z1
    fmul.s  Z2(A1),FP0      ; FP0=FP0*Z2
    fadd.s  I3(A1),FP0      ; FP0=FP0+I3
    fmove.s FP0,Z2(A1)      ; Z2=FP0
    ; Z1=A-B+R3
    ; fmove.s vB(A1),FP0      ; FP0=B
    ; fadd.s  R3(A1),FP0      ; FP0=FP0+R3
    ; fmove.s vA(A1),FP1      ; FP1=A
    ; fsub.x  FP0,FP1         ; FP1=FP1-FP0=A-FP0=A-(B+R3)
    ; fmove.s FP1,Z1(A1)      ; Z1=FP1
    fmove.s vA(A1),FP0      ; FP0=A
    fsub.s  vB(A1),FP0      ; FP0=FP0-B=A-B
    fadd.s  R3(A1),FP0      ; FP0=FP0+R3
    fmove.s FP0,Z1(A1)      ; Z1=FP0

; 120 NEXT N
    addi.w  #1,D4           ; increment N
    cmpi.w  #15,D4          ; check for end of loop
    ble     nextN           ; continue loop if not end

; 130 GOSUB 200
    bra     drawPixel       ; jump to draw pixel

drawRet:
; 140 NEXT X
    addi.w  #1,D2           ; increment X
    cmp.w   D0,D2           ; compare to X limit
    ble     nextX           ; continue loop if not end

; 160 NEXT Y
    addi.w  #2,D3           ; increment Y
    cmp.w   D1,D3           ; compare to Y limit
    ble     nextY           ; continue loop if not end

; 170 END
    lea     sEnd(PC),A4     ; get pointer to exit string
    callSYS #sysPSTRING
    movem.l (SP)+,A0-A6/D0-D7   ; restore all registers before return
    rts                     ; return to monitor

drawPixel:
    ; lea     sDraw(PC),A4    
    ; callSYS #sysPSTRING
    ; callSYS #sysNEWLINE
    ; callPWORD D2            ; print X
    ; callPWORD D3            ; print Y
    ; callPBYTE D4            ; print N
    ; callPFLOAT  I1
    ; callPFLOAT  I2
    ; callPFLOAT  I3
    ; callPFLOAT  R1
    ; callPFLOAT  R2
    ; callPFLOAT  R3
    ; callPFLOAT  S1
    ; callPFLOAT  S2
    ; callPFLOAT  Z1
    ; callPFLOAT  Z2
    ; callPFLOAT  vA
    ; callPFLOAT  vB
    ; callSYS #sysNEWLINE
    ; callSYS #sysNEWLINE
    move.w  D3,D5           ; get a copy of Y
    mulu.w  #160,D5         ; multiply by 160 to get row address
    add.w   D2,D5           ; add X to get pixel address
    move.w  D4,D6           ; get a copy of N
    and.w   #$F,D6          ; mask out high bits
    move.b  D6,D7           ; get a copy
    lsl.b   #4,D7           ; shift the copy
    or.b    D7,D6           ; both pixels will be the same color
    move.b  D6,0(A0,D5.l)   ; write the first half of the chunky pixel
    move.b  D6,0(A0,D5.l)   ; do it now
    add.l   #160,D5         ; increment address for second half of chunky pixel
    move.b  D6,0(A0,D5.l)   ; write the second half of the chunky pixel
    move.b  D6,0(A0,D5.l)   ; do it 
    bra     drawRet         ; return to calculation loop

sHead:  dc.b    'FPU Mandelbrot renderer',$0D,$0A,0,0
sEnd:   dc.b    'Render complete. Exiting.',$0D,$0A,0,0
sInit:  dc.b    'Initialization complete.',$0D,$0A,0,0
sDraw:  dc.b    '-X--|-Y--|N-|---I1---|---I2---|---I3---|---R1---|---R2---|---R3---|---S1---|---S2---|---Z1---|---Z2---|---vA---|---vB---',0,0
sNextN: dc.b    '---Z1---|---Z2---|---vA---|---vB---|---I3---|---R3---',0,0
    even

vars:
X1: ds.s    1
Y1: ds.s    1
I1: ds.s    1
I2: ds.s    1
I3: ds.s    1
R1: ds.s    1
R2: ds.s    1
R3: ds.s    1
S1: ds.s    1
S2: ds.s    1
Z1: ds.s    1
Z2: ds.s    1
vA: ds.s    1
vB: ds.s    1
LP: ds.w    1               ; loop counter