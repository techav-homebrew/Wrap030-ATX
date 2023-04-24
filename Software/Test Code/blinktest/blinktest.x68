


romBot      equ $f0000000
ramBot      equ $00000000
ramTop      equ ramBot + $0fffffff
stackInit   equ ramTop+1

busCtrlPort equ $e0000000

spioPort    equ $dc000000

; initial vector table
	ORG	0
VECTOR:
    dc.l    stackInit           ; initial SP
    dc.l    START               ; initial PC
;    dcb.l   245,romBot+START    ; fill out vector table

; initial program
START:
    lea     busCtrlPort,A0      ; get address to bus controller register
MAINLOOP:
    eori.b  #$04,(A0)           ; invert the debug LED bit
    move.l  #$fffff,D0          ; initialize counter to 1048575
TIMELOOP:
    subq.l  #1,D0               ; decrement counter
    cmpi.l  #0,D0               ; is timer at 0?
    bne     TIMELOOP            ; if no, then keep counting
    bra     MAINLOOP            ; if yes, then start over
    