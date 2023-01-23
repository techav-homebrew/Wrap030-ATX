; rotates through a short slideshow of images stored uncompressed at the end
; of this program

vidBuf0:    equ $80800000
vidBuf1:    equ vidBuf0+$8000
vidSets:    equ vidBuf0+$ffff
setVidBlank:    equ $01
setVidBuf0:     equ $00
setVidBuf1:     equ $02

; Generic macro for system calls
    MACRO callSYS
    movem.l A0-A6/D0-D7,-(SP)   ; save working registers
    move.b  \1,D1               ; load syscall number
    trap    #0                  ; call syscall handler
    movem.l (SP)+,A0-A6/D0-D7   ; restore working registers
    ENDM

    MACRO callPWORD
    movem.l A0-A6/D0-D7,-(SP)   ; save working registers
    move.w  \1,D0               ; load word to print
    move.b  #sysPWORD,D1        ; load syscall number
    trap    #0                  ; call syscall handler
    callSYS #sysPSPACE          ; follow with a space
    movem.l (SP)+,A0-A6/D0-D7   ; restore working registers
    ENDM

sysGETCHAR  equ 0
sysPUTCHAR  equ 1
sysNEWLINE  equ 2
sysPSTRING  equ 4
sysPBYTE    equ 9
sysPWORD    equ 10
sysPLONG    equ 11
sysPSPACE   equ 12


    org $10000

start:
    movem.l A0-A6/D0-D7,-(SP)   ; save all registers
    lea     sPgmHead(PC),A4     ; get pointer to program header string
    callSYS #sysPSTRING         ; and print
    callSYS #sysNEWLINE         ; finish with a newline
    lea     vidSets,A0          ; get pointer to video settings register
    move.b  #setVidBlank,(A0)   ; blank video output
imgRestart:
    move.w  imgCount,D0         ; how many images are we displaying?
    subq.w  #1,D0               ; decrement by 1 to use as index & loop counter
    lea     imgTable,A1         ; get pointer to image pointer table
    lea     vidBuf0,A3          ; get pointer to video buffer
    move.b  #setVidBuf0,D4      ; D4 holds byte to enable video buffer
imgLoadInit:
    lea     sImgHead(PC),A4     ; get pointer to header string
    callSYS #sysPSTRING         ; and print
    callPWORD D0                ; print image number
    callSYS #sysNEWLINE         ; and finish with a newline
    lsl.w   #2,D0               ; scale image number to use for word offset
    movea.l 0(A1,D0.w),A2       ; A2 holds pointer to next image
    lsr.w   #2,D0               ; and put it back
    move.l  #31999,D2           ; D2 is loop counter for image size transfer
.imgLoadLoop:
    move.b  0(A2,D2.l),D3       ; fetch next byte
    move.b  D3,0(A3,D2.l)       ; and write to video buffer
    move.b  D3,0(A3,D2.l)       ; twice, just to make sure
    dbra    D2,.imgLoadLoop     ; keep looping until all data copied to buffer
.imgDisplay:
    move.b  D4,(A0)             ; enable selected video buffer
    eor.b   #02,D4              ; toggle enabled video buffer
    move.l  A3,D5               ; fetch video buffer pointer
    eor.l   #$8000,D5           ; toggle enabled buffer
    move.l  D5,A3               ; and copy back to pointer
    lea     sImgDisp(PC),A4     ; get pointer to image display string
    callSYS #sysPSTRING         ; and print
    callPWORD D0                ; print image number
    callSYS #sysNEWLINE         ; and finish with a newline
    move.w  #$0400,D6           ; set up delay loop counter 1
.imgDelay1:
    move.l  #$0ffff,D7          ; set up delay loop counter 2
.imgDelay2:
    dbra    D7,.imgDelay2       ; delay loop 2
    dbra    D6,.imgDelay1       ; delay loop 1
    dbra    D0,imgLoadInit      ; decrement counter and move on to next image
imgDone:                        ; there are no more images to display
    lea     sPgmEndr(PC),A4     ; get program end string
    callSYS #sysPSTRING         ; print it
    callSYS #sysNEWLINE         ; and end with a newline
    bra     imgRestart          ; start playing slideshow again
    movem.l (SP)+,A0-A6/D0-D7   ; restore all registers
    rts                         ; return to monitor

sPgmHead:   dc.b    ' Slideshow Viewer',0,0
sImgHead:   dc.b    ' Loading image ',0,0
sImgDisp:   dc.b    ' Displaying image ',0,0
sPgmEndr:   dc.b    ' Slideshow complete. Restarting.',0,0

    even
imgCount:   dc.w    4

; pointers to the start of each image's data
imgTable:   dc.l    img3
            dc.l    img2
            dc.l    img1
            dc.l    img0
            dc.l    garbage

img0:
    include "kingtut.inc"
img1:
    include "68030.inc"
img2:
    include "Wrap030.inc"
img3:
    include "Wrap030Testing.inc"
garbage: