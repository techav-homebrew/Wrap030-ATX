
width:      equ 320
height:     equ 200
vidAddr:    equ $80800000
scaler:     equ 1.5         ; how much to scale I1,I2,R1,R2 per pass
loops:      equ 4           ; how many loops before starting over

; Generic macro for system calls
    MACRO callSYS
    move.l  D1,-(SP)            ; save the working register
    move.b  \1,D1               ; load syscall number
    trap    #0                  ; call syscall handler
    move.l  (SP)+,D1            ; restore the working register
    ENDM

sysGETCHAR  equ 0
sysPUTCHAR  equ 1
sysNEWLINE  equ 2
sysPSTRING  equ 4
sysPBYTE    equ 9
sysPWORD    equ 10
sysPLONG    equ 11
sysPSPACE   equ 12


;    text
    org     $00004000
start:
;    link    A6,#0-B         ; set up stack frame for local variables
    lea     variables(PC),A1    ; get pointer to variables region
    lea     vidAddr,A0      ; get address to video frame buffer
    move.l  #$0FFFF,D0      ; video register address offset
    move.b  #0,0(A0,D0.l)   ; enable video generator & set mode 0
    move.l  #$7fff,D0       ; set up loop counter
    eor.l   D1,D1           ; clear D1 to quickly clear VRAM with
clearVram:
    move.b  D1,0(A0,D0.L)   ; clear each VRAM address
    move.b  D1,0(A0,D0.L)   ; do it now
    dbra    D0,clearVram    ; loop until all VRAM cleared

    lea     vidBuf(PC),A3   ; get pointer to local RAM video buffer

; initializations
; Register-resident variables:
;   X1  -   D0
;   Y1  -   D1
;   X   -   D2
;   Y   -   D3
;   N   -   D4
varInit:
    move.w  #loops,LP(A1)   ; initialize loop counter
    move.l  #width-1,D0     ; X1=width-1
    fmove.l D0,FP0
    fmove.s FP0,X1(A1)
    move.l  #height-1,D1    ; Y1=height-1
    fmove.l D1,FP0
    fmove.s FP0,Y1(A1)
    fmove.s #-1.0,FP0       ; I1=-1.0
    fmove.s FP0,I1(A1)
    fmove.s #1.0,FP0        ; I2=1.0
    fmove.s FP0,I2(A1)
    fmove.s #-2.0,FP0       ; R1=-2.0
    fmove.s FP0,R1(A1)
    fmove.s #1.0,FP0        ; R2=1.0
    fmove.s FP0,R2(A1)

calcLoop:
    ; 30 S1=(R2-R1)/X1:S2=(I2-I1)/Y1

    ; S1=(R2-R1)/X1
    fmove.s R2(A1),FP0      ; FP0=R2
    fsub.s  R1(A1),FP0      ; FP0=FP0-R1=R2-R1
    fdiv.s  X1(A1),FP0      ; FP0=FP0/X1=(R2-R1)/X1
    fmove.s FP0,S1(A1)      ; S1=FP0

    ; S2=(I2-I1)/Y1
    fmove.s I2(A1),FP0      ; FP0=I2
    fsub.s  I1(A1),FP0      ; FP0=FP0-I1=I2-I1
    fdiv.s  Y1(A1),FP0      ; FP0=FP0/Y1=(I2-I1)/Y1
    fmove.s FP0,S2(A1)      ; S2=FP0

    ; FOR Y=0 TO Y1 STEP 2
    move.l  #0,D3           ; Y=0

nextY:
    ; I3=I1+S2*Y
    fmove.l D3,FP0          ; FP0=Y
    fmul.s  S2(A1),FP0      ; FP0=FP0*S2=Y*S2
    fadd.s  I1(A1),FP0      ; FP0=FP0+I1=(S2*Y)+I1
    fmove.s FP0,I3(A1)      ; I3=FP0

    ; FOR X=0 TO X1
    move.l  #0,D2           ; X=0

nextX:
    ; 70 R3=R1+S1*X:Z1=R3:Z2=I3

    ; R3=R1+S1*X
    fmove.l D2,FP0          ; FP0=X
    fmul.s  S1(A1),FP0      ; FP0=FP0*S1=X*S1
    fadd.s  R1(A1),FP0      ; FP0=FP0+R1=(X*S1)+R1
    fmove.s FP0,R3(A1)      ; R3=FP0

    ; Z1=R3
    fmove.s FP0,Z1(A1)      ; Z1=FP0=R3

    ; Z2=I3
    fmove.s I3(A1),FP0      ; FP0=I3
    fmove.s FP0,Z2(A1)      ; Z2=FP0=I3

    ; FOR N=0 TO 15
    move.w  #0,D4           ; N=0

nextN:
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
    fadd.s  vB(A1),FP0      ; FP0=A+B
    fcmp.s  #4.0,FP0        ; FP0-4.0
    fbgt    drawPixel       ; if FP0>4.0, goto [drawPixel]

    ; 110 Z2=2*Z1*Z2+I3:Z1=A-B+R3

    ; Z2=2*Z1*Z2+I3
    fmove.s Z1(A1),FP0      ; FP0=Z1
    fadd.x  FP0,FP0         ; FP0=FP0+FP0=Z1+Z1=Z1*2
    fmul.s  Z2(A1),FP0      ; FP0=FP0*Z2
    fadd.s  I3(A1),FP0      ; FP0=FP0+I3
    fmove.s FP0,Z2(A1)      ; Z2=FP0

    ; Z1=A-B+R3
    fmove.s vA(A1),FP0
    fsub.s  vB(A1),FP0
    fadd.s  R3(A1),FP0
    fmove.s FP0,Z1(A1)

    ; NEXT N
    addi.w  #1,D4           ; increment N
    cmpi.w  #15,D4          ; compare to loop limit
    ble     nextN           ; if less than limit then continue N loop

    ; GOSUB [drawPixel]
    bra     drawPixel

drawRet:
    ; NEXT X
    addi.l  #1,D2           ; increment X
    cmp.l   D0,D2           ; compare X to X1
    ble     nextX           ; if X<X1, then continue X loop

    ; NEXT Y
    addi.l  #1,D3           ; increment Y
    cmp.l   D1,D3           ; compare Y to Y1
    ble     nextY           ; if Y<Y1, then continue Y loop

; end of calculation loop.
; this would be a good place to update the initial parameters to zoom in on a
; region of the fractal and start drawing again
    move.w  LP(A1),D7       ; get loop counter
    subi.w  #1,D7           ; decrement loop counter
    beq     varInit         ; start over if loop counter = 0
    move.w  D7,LP(A1)       ; store updated loop counter
    fmove.s #scaler,FP1
    fmove.s I1(A1),FP0      ; I1=I1/scaler
    fdiv.x  FP1,FP0
    fmove.s FP0,I1(A1)
    fmove.s I2(A1),FP0      ; I2=I2/scaler
    fdiv.x  FP1,FP0
    fmove.s FP0,I2(A1)
    fmove.s R1(A1),FP0      ; R1=R1/scaler
    fdiv.x  FP1,FP0
    fmove.s FP0,R1(A1)
    fmove.s R2(A1),FP0      ; R2=R2/scaler
    fdiv.x  FP1,FP0
    fmove.s FP0,R2(A1)
    bra     calcLoop        ; run next loop

; draw the pixel we just calculated
drawPixel:
    move.l  D3,D5           ; get a copy of Y
    mulu.l  #160,D5         ; multiply by 160 to get row address
    move.l  D2,D6           ; get a copy of X
    lsr.l   #1,D6           ; get rid of the low bit
    add.l   D6,D5           ; add X to row address to get pixel address
    move.b  0(A3,D5.l),D6   ; get current video data
    move.w  D4,D7           ; copy N
    andi.w  #$F,D7          ; mask off high bits of N
    btst    #0,D2           ; check that low bit
    beq     .draw1          ; bit 0 is clear

    andi.b  #$F0,D6         ; mask off low bits of read video data
    or.b    D7,D6           ; combine new video data with existing
    bra     .drawEnd
.draw1:
    andi.b  #$0F,D6         ; mask off high bits of read video data
    lsl.b   #4,D7           ; shift new video data into position
    or.b    D7,D6           ; combine new video data with existing

.drawEnd:
    move.b  D6,0(A3,D5.l)   ; write to video buffer
    move.b  D6,0(A0,D5.l)   ; and write to VRAM
    move.b  D6,0(A0,D5.l)   ; do it now
    bra     drawRet         ; return to calculation loop


;    bss
; variables stored at end of code
variables:
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
vidBuf: ds.b 1