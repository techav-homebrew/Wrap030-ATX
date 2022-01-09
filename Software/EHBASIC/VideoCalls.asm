; 2022/1/7 techav
; function calls for EhBASIC for drawing to a linear frame buffer

    INCLUDE "EhBasic030.inc"

; these should immediately follow the global variables specified in the include file
;pixX1:  ds.w    1           ; temporary coordinate variable storage
;pixY1:  ds.w    1
;pixX2:  ds.W    1
;pixY2:  ds.w    1
;pixDat: ds.b    1           ; temporary video data storage
;dumbyte: ds.B   1           ; word align
;******: Instead of global variables, we'll need to use the stack.
pixE2:      EQU 20
pixErr:     EQU 18
pixSY:      EQU 16
pixSX:      EQU 14
pixDY:      EQU 12
pixDX:      EQU 10
pixY2:      EQU 8
pixX2:      EQU 6
pixY1:      EQU 4
pixX1:      EQU 2
pixDat:     EQU 0

vidBuf:     EQU $001FA700   ; frame buffer base address

; in lieu of a working linker, copy necessary EhBASIC function addresses here
LAB_GTWO:   EQU $00271760    
LAB_SCGB:   EQU $00270DD4 
LAB_GADB:   EQU $002717A2
LAB_GTBY:   EQU $0027174C
LAB_EVNM:   EQU $00270C6A
LAB_EVIR:   EQU $0027112E
LAB_1C01:   EQU $00270DD8


    ORG $00260000           ; this code will sit in ROM page 6
; start with a jump table
setPixel:   bra     setPixel1
clrPixel:   bra     clrPixel1
fillRow:    bra     fillRow1
fillBuf:    bra     fillBuf1
drawLine:   bra     drawLine1

    ORG $00260100

;******************************************************************************
; setPixel
;   sets (writes 1) to specified pixel
; CALL SETPIXEL X,Y
setPixel1:
    movem.L D0-D2,-(SP)     ; save working registers (unnecessary?)
;    move.b  #1,pixDat(A3)   ; when the time comes, set the specified byte
;    bra     pixManip        ; jump to shared funtion
    lea     -6(SP),SP       ; set up stack frame for local variables
    move.w  #-1,pixDat(SP)  ; save pixel data (set) to stack
    bra     pixManip        ; jump to shared draw function

;******************************************************************************
; clrPixel
;   clear (writes 0) to specified pixel
; CALL CLRPIXEL X,Y
clrPixel1:
    movem.L D0-D2,-(SP)     ; save working registers
;    move.b  #0,pixDat(A3)   ; when the time comes, clear the specified byte
    lea     -6(SP),SP       ; set up stack frame for local variables
    move.w  #0,pixDat(SP)   ; save pixel data (clear) to stack

pixManip:
;   JSR     LAB_GTWO        ; get word parameter in D0
;   move.W  D0,pixX1(A3)    ; save for now as X parameter
;   JSR     LAB_GTWO        ; get second word parameter
;   move.w  D0,pixY1(A3)    ; and save

    jsr     LAB_EVNM        ; evaluate expression & check it's numeric
    jsr     LAB_EVIR        ; evaluate integer expression
    move.w  D0,pixX1(SP)    ; save X parameter
    jsr     LAB_1C01        ; scan for ","
    jsr     LAB_EVNM        ; evaluate expression & check it's numeric
    jsr     LAB_EVIR        ; evaluate integer expression
    move.w  D0,pixY1(SP)    ; save Y parameter

pixManipDraw:
    lea     vidBuf,A0       ; get base buffer address
    move.w  pixX1(SP),D1    ; get x coordinate
    move.w  D1,D2           ; save a copy
    lsr.w   #3,D1           ; shift out bit select bytes from X (divide by 8)
    eor.w   #1,D1           ; invert low bit to match expected byte ordering
    and.w   #$3F,D1         ; mask column bits    
    and.w   #$1ff,D0        ; mask row bits
    lsl.w   #6,D0           ; shift in row select bytes from Y (multiply by 64)
    or.w    D0,D1           ; combine for byte offset
    move.b  0(A0,D1.w),D0   ; get current video data from buffer
    and.w   #$7,D2          ; mask out bit selection from X parameter
    eor.w	#$7,D2          ; selectively invert bit selection bits
    cmp.b   #0,pixDat(SP)   ; do we set or clear?
    beq.s   .pixClr         ; jump to clear if pixDat is 0
    bset    D2,D0           ; otherwise, set the specified byte
    bra     .pixEnd         ; then jump to the end
.pixClr:
    bclr    D2,D0           ; clear the specified byte
.pixEnd:
    move.b  D0,0(A0,D1.w)   ; copy modified byte back to video buffer
    move.b  D0,0(A0,D1.w)   ; no really, copy it to the video buffer
    lea     6(SP),SP        ; dispose of stack frame
    movem.L (A7)+,D0-D2     ; restore working registers
    rts                     ; and return

;******************************************************************************
; fillRow
;   writes specified byte to a single row
; CALL FILLROW ROW,BYTE
fillRow1:
    movem.l D0-D1,-(A7)     ; save working registers
    jsr     LAB_GADB        ; get address parameter in A0 and byte in D0
    move.l  A0,D1           ; move address parameter into D1
    lea     vidBuf,A0       ; get base buffer address
    lsl.w   #6,D1           ; multiply row by 64
    lea     0(A0,D1.w),A0   ; add row offset to base pointer
    move.w  #63,D1          ; get loop counter, 64 bytes per row
.fillLoop:
    move.b  D0,(A0,D1.w)    ; write byte
    move.b  D0,(A0,D1.w)    ; no really, write byte
    dbra    D1,.fillLoop    ; continue for rest of line
    movem.l (A7)+,D0-D1     ; restore working registers
    rts                     ; and return

;******************************************************************************
; fillBuf
;   writes specified byte to entire frame buffer
; CALL FILLBUF BYTE
fillBuf1:
    movem.l D0-D1,-(A7)     ; save working registers
    jsr     LAB_GTBY        ; get byte parameter in D0
    lea     vidBuf,A0       ; get base buffer address
    move.w  #$5580,D1       ; get loop counter
.fillLoop:
    move.b  D0,(A0)         ; write byte to frame buffer
    move.b  D0,(A0)+        ; no really, write the byte; and increment address
    subq.w  #1,D1           ; decrement loop counter
    bne.s   .fillLoop       ; loop until complete
    movem.l (A7)+,D0-D1     ; restore working registers
    rts                     ; and return

;******************************************************************************
; drawLine
;   draws line from (X1,Y1) to (X2,Y2) with color Z (0|1)
; CALL DRAWLINE X1,Y1,X2,Y2,Z
;
; ported from:https://www.rosettacode.org/wiki/Bitmap/Bresenham%27s_line_algorithm#C
; written using structured assembly directives for easy68k

drawLine1:
    movem.l D0-D1,-(SP)     ; save working registers
    lea     -22(SP),SP      ; set up stack frame for local variables
    jsr     LAB_EVNM        ; evaluate expression & check it's numeric
    jsr     LAB_EVIR        ; evaluate integer expression
    move.w  D0,pixX1(SP)    ; save X1 parameter
    jsr     LAB_1C01        ; scan for ","
    jsr     LAB_EVNM        ; evaluate expression & check it's numeric
    jsr     LAB_EVIR        ; evaluate integer expression
    move.w  D0,pixY1(SP)    ; save Y1 parameter
    jsr     LAB_1C01        ; scan for ","
    jsr     LAB_EVNM        ; evaluate expression & check it's numeric
    jsr     LAB_EVIR        ; evaluate integer expression
    move.w  D0,pixX2(SP)    ; save X2 parameter
    jsr     LAB_1C01        ; scan for ","
    jsr     LAB_EVNM        ; evaluate expression & check it's numeric
    jsr     LAB_EVIR        ; evaluate integer expression
    move.w  D0,pixY2(SP)    ; save Y2 parameter
    jsr     LAB_1C01        ; scan for ","
    jsr     LAB_EVNM        ; evaluate expression & check it's numeric
    jsr     LAB_EVIR        ; evaluate integer expression
    cmpi.b  #0,D0           ; check if 0
    beq     .linepen0       ; 
    move.b  #1,pixDat(SP)   ; set pen for set
    bra     .startline
.linepen0:
    move.b  #0,pixDat(SP)   ; set pen for clear
.startline:
.lineInitX:
    move.w  pixX1(SP),D0    ; fetch x0
    move.w  pixX2(SP),D1    ; fetch x1
    IF.W D0 <LT> D1 THEN.S
        move.w  #1,pixSX(SP)    ; sx=1
        sub.w   D0,D1           ; dx=x1-x0
        move.w  D1,pixDX(SP)    ; and save dx
    ELSE.S
        move.w  #-1,pixSX(SP)   ; sx=-1
        sub.w   D1,D0           ; dx=x0-x1
        move.w  D0,pixDX(SP)    ; and save dx
    ENDI
.lineInitY:
    move.w  pixY1(SP),D0    ; fetch y0
    move.w  pixY2(SP),D1    ; fetch y1
    IF.W D0 <LT> D1 THEN.S
        move.w  #1,pixSY(SP)    ; sy=1
        sub.w   D0,D1           ; dy=y1-y0
        move.w  D1,pixDY(SP)    ; and save dy
    ELSE.S
        move.w  #-1,pixSY(SP)   ; sy=-1
        sub.w   D1,D0           ; dy=y0-y1
        move.w  D0,pixDY(SP)    ; and save dy
    ENDI
.lineInitErr:
    move.w  pixDX(SP),D0    ; fetch dx
    move.w  pixDY(SP),D1    ; fetch dy
    IF.W D0 <GT> D1 THEN.S
        move.w  D0,pixErr(SP)   ; err=dx
    ELSE.S
        neg.w   D1              ; err=-dy
        move.w  D1,pixErr(SP)   ; and save dy
    ENDI
.lineloop:
    WHILE <T> DO.S
        ; call set pixel here
        movea.l SP,A0           ; save stack pointer
        pea     .lineloop2(PC)  ; push return address to stack
        movem.l D0-D2,-(SP)     ; save registers as needed for next sub
        move.w  pixY1(A0),-(SP) ; push y0 value to stack
        move.w  pixX1(A0),-(SP) ; push x0 value to stack
        move.w  pixDat(A0),-(SP)    ; push pixel data value to stack
        bra     pixManipDraw    ; draw pixel
.lineloop2:
        move.w  pixX2(SP),D0    ; fetch x1
        move.w  pixY2(SP),D1    ; fetch y1
        IF.W pixX1(SP) <EQ> D0 AND.W pixY1(SP) <EQ> D1 THEN.S
            bra lineEnd
        ENDI
.lineloopUpdateErr:
        move.w  pixErr(SP),D0   ; fetch err
        move.w  D0,pixE2(SP)    ; e2=err
.lineloopUpdateX:
        move.w  pixDX(SP),D1    ; fetch dx
        neg.w   D1              ; temp = -dx
        IF.W D0 <GT> D1 THEN.S  ; if e2 > -dx
            move.w  pixDY(SP),D1    ; fetch dy
            sub.w   D1,D0           ; err=err-dy
            move.w  D0,pixErr(SP)   ; save new err
            move.w  pixX1(SP),D0    ; fetch x0
            add.w   pixSX(SP),D0    ; x0=x0+sx
            move.w  D0,pixX1(SP)    ; save new x0
        ENDI
.lineloopUpdateY:
        move.w  pixDY(SP),D0        ; fetch dy
        IF.W pixE2(SP) <LT> D0 THEN.S
            move.w  pixDX(SP),D0    ; fetch dx
            add.w   D0,pixErr(SP)   ; err=err+dx
            move.w  pixSY(SP),D0    ; fetch sy
            add.w   D0,pixY1(SP)    ; y0=y0+sy
        ENDI
    ENDW
lineEnd:
    lea     22(SP),SP   ; dismantle stack frame
    movem.l (SP)+,D0-D1 ; restore saved registers
    rts



;.lineloop:
;    movea.L SP,A0           ; save stack pointer
;    pea     .lineloop2      ; push return address to stack
;    movem.L D0-D2,-(SP)     ; save working registers (needed for next sub)
;    move.w  pixY1(A0),-(SP) ; push y0 value to stack
;    move.w  pixX1(A0),-(SP) ; push y0 value to stack
;    move.w  pixDat(A0),D0   ; fetch pixel data
;    move.w  D0,-(SP)        ; and push to stack
;    bra     pixManipDraw    ; draw pixel
;.lineloop2:
