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
vidBufLen:  EQU 21888       ; frame buffer length
vidBufEnd:  EQU vidBuf+vidBufLen-1  ; frame buffer end address

fontData:   EQU $00250000

; in lieu of a working linker, copy necessary EhBASIC function addresses here
LAB_GTWO:   EQU $00271760    
LAB_SCGB:   EQU $00270DD4 
LAB_GADB:   EQU $002717A2
LAB_GTBY:   EQU $0027174C
LAB_EVNM:   EQU $00270C6A
LAB_EVIR:   EQU $0027112E
LAB_1C01:   EQU $00270DD8
LAB_XERR:   EQU $002701AA


    ORG $00260000           ; this code will sit in ROM page 6
; start with a jump table
setPixel:   bra     setPixel1
clrPixel:   bra     clrPixel1
fillRow:    bra     fillRow1
fillBuf:    bra     fillBuf1
drawLine:   bra     errUnimp
scrollV:    bra     scrollV1
scrollVX:   bra     scrollVX1
drawChar:   bra     drawChar1
            bra     errUnimp
            bra     errUnimp
            bra     errUnimp
            bra     errUnimp
            bra     errUnimp
            bra     errUnimp
            bra     errUnimp
            bra     errUnimp
            bra     errUnimp
            bra     errUnimp
            bra     errUnimp
            bra     errUnimp
            bra     errUnimp

    ORG $00260100

;******************************************************************************
; error unimplemented
errUnimp:
    MOVEQ   #$2E,d7         ; error code $2E "Not implemented" error
    JMP     LAB_XERR        ; do error #d7, then warm start

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
    MOVEQ   #$2E,d7         ; error code $2E "Not implemented" error
    JMP     LAB_XERR        ; do error #d7, then warm start

;******************************************************************************
; scrollV
;   scrolls entire screen up/down by 1 line
; CALL SCROLLV DIR
scrollV1:
    jsr     LAB_GTBY        ; get byte parameter in D0
    lea     vidBuf,A0       ; get base video buffer pointer
    cmp.b   #0,D0           ; check direction
    beq     scrollVdn       ; if 0, then scroll down
                            ; else scroll up

scrollVup:
    FOR.W D0 = #64 TO #21887 DO.S
        move.b  0(A0,D0.w),-64(A0,D0.w) ; move by back 64 addresses
    ENDF
    bra     endScroll       ; go to end

scrollVdn:
    FOR.W D0 = #21824 TO #0 BY #-1 DO.S
        move.b  0(A0,D0.w),64(A0,D0.w)  ; move up by 64 addresses
    ENDF

endScroll:
    RTS                     ; nothing else to do here

;******************************************************************************
; scrollVX
;   scrolls entire screen up/down by X lines
; CALL SCROLLV OFFSET
;   offset is signed integer range (-8 to -1) or (1 to 7)
scrollVX1:
    jsr     LAB_GTBY        ; get byte parameter in DO
    move.b  D0,D1           ; copy to D1

    btst    #7,D1           ; check sign bit for sign extend
    beq.s   .scrollVXsexneg ; jump to sign extend negative
    andi.l  #$00000007,D1   ; sign extend positive
    bra     .scrollVXmul    ; jump to offset multiply
.scrollVXsexneg:
    ori.l   #$fffffff8,D1   ; sign extend negative
.scrollVXmul:
    asl.l   #6,D1           ; multiply by 64 to get address offset
    cmpi.b  #0,D0           ; check initial offset
    beq.s   scrollVXend     ; offset is 0, skip to end
    blt.s   scrollVXpos     ; offset is positive
    bgt.s   scrollVXneg     ; offset is negative
scrollVXend:
    rts

scrollVXpos:
    ; positive offset means each byte is copied (64*offset) bytes forward
    ; so we need to start copying from the end of the buffer and move back
    move.w  #vidBufLen,D0   ; copy buffer length into D0
    sub.w   D1,D0           ; subtract multiplied offset from loop counter
    lea     vidBufEnd,A0    ; A0 points to end of buffer
    suba.l  D1,A0           ; subtract multiplied offset from base pointer
.scrollVXposLoop:
    move.b  (A0),0(A0,D1.w) ; copy byte to address+offset
    subq.l  #1,A0           ; decrement base pointer
    dbra    D0,.scrollVXposLoop ; continue loop until counter expired
    bra.s   scrollVXend     ; jump to end

scrollVXneg:
    ; negative offset means each byte is copied (64*offset) bytes backward
    ; so we need to start copying from the start of the buffer and move fore
    move.w  #vidBufLen,D0   ; copy buffer length into D0
    add.w   D1,D0           ; subtract multiplied offset from loop counter
    move.l  D1,D2           ; copy multiplied offset
    neg.l   D2              ; make positive
    lea     vidBuf,A0       ; A0 points to start of buffer
    adda.l  D2,A0           ; add starting offset to base pointer
.scrollVXnegLoop:
    move.b  (A0),0(A0,D1.w) ; copy byte to address+offset (offset is negative here)
    addq.l  #1,A0           ; increment base pointer
    dbra    D0,.scrollVXnegLoop ; continue loop until counter expired
    bra.s   scrollVXend     ; jump to end

;******************************************************************************
; drawChar
;   prints a single character at a given position on screen
; CALL DRAWCHAR X,Y,C
drawChar1:
    movem.l D0-D2/A1,-(SP)  ; save working registers
    jsr     LAB_EVNM        ; evaluate expression & check it's numeric
    jsr     LAB_EVIR        ; evaluate integer expression
    andi.w  #$3F,D0         ; mask out invalid X values
    move.w  D0,-(SP)        ; push X value to stack for later use
    jsr     LAB_EVNM        ; evaluate expression & check it's numeric
    jsr     LAB_EVIR        ; evaluate integer expression
    andi.w  #$3F,D0         ; mask out invalid values
    moveq   #9,D1           ; get ready to shift Y into position
    lsl.w   D1,D0           ; shift Y position for offset
    move.w  (SP),D1         ; pop X value off stack
    or.w    D1,D0           ; combine X & Y positions into pointer offset
    move.w  D0,(SP)         ; push to stack to save for later
                            ; (SP) is vidbuffer offset for specified position
    jsr     LAB_1C01        ; scan for ","
    jsr     LAB_GTBY        ; get byte parameter in D0 (char to print)
    eor.L   D1,D1           ; clear D1
    move.b  D0,D1           ; copy char into D1
    lsl.w   #3,D1           ; shift into offset location
                            ; D1 is font data offset to specified character
    lea     fontData,A0     ; get pointer to font data
    lea     vidBuf,A1       ; get pointer to video buffer
    move.w  (SP)+,D0        ; get vidbuffer offset
                            ; D0 is vidbuffer offset for specified position
    FOR D2 = 0 TO 7 DO.S
        move.b  0(A0,D1.w),$000(A1,D0.w)    ; copy video data
        addq.w  #1,D1                       ; increment font offset
        addi.w  #$40,D0                     ; increment video offset
    ENDF
    movem.l (SP)+,D0-D2/A1  ; restore working registers
    rts