*-----------------------------------------------------------
* Title      : Wrap030 Initial Test Program
* Written by : techav
* Date       : 2021/12/27
* Description: Performs initial tests to confirm hardware
*            : is operating as expected.
*-----------------------------------------------------------

romBot	equ	$00200000
ramBot	equ	$00000000
ramPage1	equ	ramBot+$80000
ramTop	equ	ramBot+$1FFFFF
stackInit	equ	ramTop+1

aciaCom	equ	$00380000
aciaDat	equ	aciaCom+4
aciaSet	equ	$16

overlayPort	equ	$00300000

	ORG	romBot

; macros
prntChr	MACRO
	eor.l	D1,D1	; clear loop counter
chrLp\@
	btst	#1,aciaCom	; check if ACIA Tx register is empty
	;beq.s	chrLp\@	; loop until empty
	bne.s	chrOut\@	; if empty, skip ahead and output byte
	addq.l	#1,D1	; increment loop counter
	cmp.l	#1000,D1	; limit 1000 loops
	bne.s	chrLp\@	; if not at limit, then continue loop
chrOut\@
	move.b	D0,aciaDat	; output character to ACIA
	ENDM

prntStr	MACRO
prntLp\@
	move.b	(A1)+,D0	; get next byte of string
	cmp.b	#0,D0	; check for null terminator
	beq.s	prntDn\@	; if null, exit print loop
	prntChr		; call print character macro
	bra.s	prntLp\@	; continue loop and print next character
prntDn\@
	nop		; end macro
	ENDM

prntFail	MACRO
	lea	strFailed,A1	; load failure string
	prntStr
	nop
	ENDM

; vector table
	ORG    romBot
VECTOR:
	;dc.l	START	; initial PC
	;dc.l	stackInit	; initial SP
	dc.l	stackInit	; initial SP
	dc.l	START	; initial PC
	dcb.l	254,intHndlr	; initial vector handler

; this is where the program actually starts	
	ORG romBot+$1000
START:			; first instruction of program
	move.l	#stackInit,SP	; initialize stack pointer
	;lea	aciaCom,A0	; get ACIA address
	;move.b	#$03,(A0)	; soft reset ACIA
	move.b	#$03,aciaCom
	nop		; and wait before configuring
	nop
	nop
	nop
	;move.b	#aciaSet,(A0)	; configure ACIA
	move.b	#aciaSet,aciaCom
	nop
	nop
	nop
	nop
	move.b	#$20,aciaDat	; just a test.
	lea	strAciaInit(PC),A1	; get address of ACIA init string
	prntStr

ClearOverlay:
	move.l	#0,overlayPort	; disable startup overlay
	lea	strOverlay(PC),A1	; get confirmation string
	prntStr

ramTest1:
	move.l	#$A5A5A5A5,D0	; check if overlay is properly disabled
	move.l	D0,ramBot	; by writing pattern to RAM page 0
	move.l	ramBot,D1	; and checking if it matches
	cmp.l	D1,D0	; 
	bne	ramTest1err1	; error if no match
	lea	strSuccess,A1
	prntStr
	bra	ramTest2	; move on to next test
ramTest1err1:
	prntFail
	bra	ramTest2	; move on to next test

ramTest2:
	lea	strDatBusTst(PC),A1	;
	prntStr
	eor.l	D0,D0	; clear D0 register
	move.l	D0,D1	; clear D1 also 
	lea	ramPage1,A0	; get ram test address
	;move.l	D0,(A0)	; clear first memory address
	;move.b	#$5A,D0	; get test pattern ($5A000000)
	;move.b	D0,(A0)	; write test pattern to memory
	;move.l	(A0),D1	; read test pattern from memory
	move.l	#0,(A0)	; clear memory address to start
	move.b	#$A1,0(A0)	; write test pattern bytes
	move.b	#$52,1(A0)	;  to memory
	move.b	#$3A,2(A0)	;
	move.b	#$45,3(A0)	;
	move.l	(A0),D1	; read back byte from memory
	move.l	#$A1523A45,D0	; test pattern comparison
	cmp.l	D1,D0	; check if it matches
	bne	ramTest2err1	; error if no match
	lea	strSuccess,A1	; load success string
	prntStr
	bra	ramTest3	; move on to next test
ramTest2err1:
	prntFail
	bra	ramTest3
	
ramTest3:
	lea	strRamTest3(PC),A1	; print header string
	prntStr
	eor.l	D7,D7	; D7 holds constant zero
	
; write 0 to all memory address, moving up
	eor.l	D0,D0	; D0 holds pattern to write ($00000000)
	move.l	#ramBot,A0	; A0 holds memory pointer
	move.l	#(ramTop+1)>>2,D2	; D2 holds loop counter
  ramTest31p1:
	move.l	D0,(A0)+	; write pattern to memory & increment pointer
	subq.l	#1,D2	; decrement loop counter
	cmp.l	D7,D2	; check end of loop
	bne	ramTest31p1	; continue loop until all memory is tested
	
; read 0 from all memory addresses, & write $AAAAAAAA; moving up
	move.l	D0,D3	; D3 holds previous test pattern ($00000000)
	move.l	#$AAAAAAAA,D0	; D0 holds pattern to write ($AAAAAAAA)
	move.l	#ramBot,A0	; A0 holds memory pointer
	move.l	#(ramTop+1)>>2,D2	; D2 holds loop counter
	eor.l	D1,D1	; D1 holds read results
  ramTest3lp2:
	move	(A0),D1	; read byte from last test
	cmp.l	D3,D1	; compare with previous pattern
	bne	ramTest3err1	; branch if they don't match
	move.l	D0,(A0)+	; write new pattern to memory & increment pointer
	subq.l	#1,D2	; decrement loop counter
	cmp.l	D7,D2	; check end of loop
	bne	ramTest3lp2	; continue loop until all memory is tested

; read $AAAAAAAA from all memory addresses, & write 0; moving down
	move.l	D0,D3	; D3 holds previous test pattern ($AAAAAAAA)
	eor.l	D0,D0	; D0 holds pattern to write ($00000000)
	move.l	#ramTop+1,A0	; A0 holds memory pointer
	move.l	#(ramTop+1)>>2,D2	; D2 holds loop counter
	eor.l	D1,D1	; D1 holds read results
  ramTest3lp3:
	move.l	-(A0),D1	; decrement counter and read byte from last test
	cmp.l	D3,D1	; compare with previous pattern
	bne	ramTest3err2	; branch if they don't match
	move.l	D0,(A0)	; write new pattern to memory
	subq.l	#1,D2	; decrement loop counter
	cmp.l	D7,D2	; check end of loop
	bne	ramTest3lp3	; continue loop until all memory is tested

; read $00000000 from all memory addresses; moving down
	move.l	D0,D3	; D3 holds previous test pattern ($00000000)
	move.l	#ramTop+1,A0	; A0 holds memory pointer
	move.l	#(ramTop+1)>>2,D2	; D2 holds loop counter
	eor.l	D1,D1	; D1 holds read results
  ramTest3lp4:
  	move.l	-(A0),D1	; decrement counter and read byte from last test
  	cmp.l	D3,D1	; compare with previous pattern
  	bne	ramTest3err3	; branch if they don't match
  	subq.l	#1,D2	; decrement loop counter
  	cmp.l	D7,D2	; check end of loop
  	bne	ramTest3lp4	; continue loop until all memory is tested

; finished with memory test 3
	lea	strSuccess,A1	; load success string
	prntStr
	bra	ramTestEnd

ramTest3err1:
ramTest3err2:
ramTest3err3:
	prntFail
	bra	ramTestEnd

ramTestEnd:
	lea	strHalt(PC),A1	; get halt string
	prntStr
	stop	#$3700	; disable trace & interrupts, then stop.

intHndlr:
	lea	strIntErr(PC),A1	; get interrupt error string
	prntStr		; and print
	jmp	START	; jump back to very beginning	


strAciaInit:
	dc.b	$0D,$0A,'ACIA init complete.',$0D,$0A,0
strOverlay:
	dc.b	'Attempting to disable overlay ... ',0
strFailed:
	dc.b	'Failed',$0D,$0A,0
strSuccess:
	dc.b	'Success',$0D,$0A,0
strDatBusTst:
	dc.b	'Testing data bus byte ordering ... ',0
strRamTest3:
	dc.b	'Testing main memory ... ',0
strHalt:
	dc.b	'Halting.',$0D,$0A,0
strIntErr:
	dc.b	$0D,$0A,'Unexpected exception.',$0D,$0A,0
	
	
	

* Put program code here

    SIMHALT             ; halt simulator

* Put variables and constants here

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~0~
*~Tab size~4~
