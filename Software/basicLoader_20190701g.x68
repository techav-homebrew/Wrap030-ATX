;-----------------------------------------------------------
; Title      :
; Written by :
; Date       :
; Description:
;-----------------------------------------------------------
romBot	equ	$00000000
romSect0	equ	romBot+$00000
romSect1	equ	romBot+$10000
romSect2	equ	romBot+$20000
romSect3	equ	romBot+$30000
romSect4	equ	romBot+$40000
romSect5	equ	romBot+$50000
romSect6	equ	romBot+$60000
romSect7	equ	romBot+$70000
romTop	equ	$0007FFFF
aciaBase	equ	$00080000	; Base address for ACIA
aciaData	equ	aciaBase+4
aciaStat	equ	aciaBase
aciaComm	equ	aciaBase
;aciaCtrl	equ	aciaBase
periph2Base	equ	$00100000
periph3Base	equ	$00180000
ramBot	equ	$00280000
ramTop128	equ	$002FFFFF
ramTop512	equ	$003FFFFF
initStack	equ	$00300000	;initial stack pointer assumes only 128k RAMS

LF	equ	$0A
CR	equ	$0D

	MEMORY	ROM	romBot,romTop

CODE	EQU	0
DATA	EQU	1
RAM	EQU	2
	
	SECTION	CODE
	org	romSect0

;***********************************************************

prntChr	MACRO
chrLp\@	btst	#1,aciaStat	;check if TX register empty
	beq.s	chrLp\@	;loop until empty
	move.b	D0,aciaData	;output byte
	ENDM

prntStr	MACRO
prntLp\@	move.b	(A1)+,D0	;get next byte of string
	cmp.b	#0,D0	;check for null terminator
	beq.s	prntDn\@	;if null, exit print loop
	prntChr		;print Character macro
	bra.s	prntLp\@	;print next character
prntDn\@	nop		;end macro
	ENDM

prntNyb	MACRO
	move.l	D0,D2	;save a copy
	and.b	#$F,D0	;mask upper nybble
	cmp.b	#9,D0	;check if letter or number
	bgt.s	nybLtr\@	;letter
	add.b	#$30,D0	;add $30 to convert to ASCII number
	bra.s	nybPrnt\@	;skip to print
nybLtr\@	add.b	#$37,D0	;add $37 to convert to ASCII letter
nybPrnt\@	prntChr		;print Character macro
	move.l	D2,D0	;restore copy
	ENDM

prntByte	MACRO
	ROR.b	#4,D0	;move upper nybble into position
	prntNyb		;print nybble macro
	ROR.b	#4,D0	;move lower nybble back into position
	prntNyb		;print nybble macro
	ENDM

prntWord	MACRO
	move.b	#8,D1	;set up our rotate length
	ror.w	D1,D0	;rotate upper byte into position
	prntByte		;print byte macro
	move.b	#8,D1	;set up our rotate length
	ror.w	D1,D0	;rotate upper byte into position
	prntByte		;print byte macro
	ENDM

prntLWord	MACRO
	swap	D0	;swap upper word into position
	prntWord		;print word macro
	swap	D0	;swap lower word back into position
	prntWord		;print word macro
	ENDM

;***********************************************************

			;MC68030 vector table
	dc.l	initStack	;000 - initial SP
	dc.l	START	;004 - initial PC
	dcb.l	254,intHndlr	;245 pointers to generic handler

intHndlr:	movem.l	D0-D7/A0-A6,-(SP)	;save all registers
	movea.l	#tblIntTxt,A0	;get pointer to string table
	move.w	$42(SP),D1	;get vector offset from stack frame
	andi.l	#$FFF,D1	;mask out upper word & type from vector offset
	movea.l	(A0,D1.w),A1	;get interrupt string pointer
	prntStr		;and print the string
	
	movea.l	#txtPC,A1	
	prntStr
	move.L	$3E(SP),D0
	prntLWord
	
	movea.l	#txtSR,A1
	prntStr
	move.w	$3C,D0
	prntWord
	
	movea.l	#txtA7,A1
	prntStr
	move.l	SP,D0
	sub.l	#$44,D0
	prntLWord
	
	movea.l	#txtA6,A1	
	prntStr
	move.L	$38(SP),D0
	prntLWord
	
	movea.l	#txtA5,A1	
	prntStr
	move.L	$34(SP),D0
	prntLWord
	
	movea.l	#txtA4,A1	
	prntStr
	move.L	$30(SP),D0
	prntLWord
	
	movea.l	#txtA3,A1	
	prntStr
	move.L	$2C(SP),D0
	prntLWord
	
	movea.l	#txtA2,A1	
	prntStr
	move.L	$28(SP),D0
	prntLWord
	
	movea.l	#txtA1,A1	
	prntStr
	move.L	$24(SP),D0
	prntLWord
	
	movea.l	#txtA0,A1	
	prntStr
	move.L	$20(SP),D0
	prntLWord
	
	movea.l	#txtD7,A1	
	prntStr
	move.L	$1C(SP),D0
	prntLWord
	
	movea.l	#txtD6,A1	
	prntStr
	move.L	$18(SP),D0
	prntLWord
	
	movea.l	#txtD5,A1	
	prntStr
	move.L	$14(SP),D0
	prntLWord
	
	movea.l	#txtD4,A1	
	prntStr
	move.L	$10(SP),D0
	prntLWord
	
	movea.l	#txtD3,A1	
	prntStr
	move.L	$0C(SP),D0
	prntLWord
	
	movea.l	#txtD2,A1	
	prntStr
	move.L	$08(SP),D0
	prntLWord
	
	movea.l	#txtD1,A1	
	prntStr
	move.L	$04(SP),D0
	prntLWord
	
	movea.l	#txtD0,A1	
	prntStr
	move.L	$00(SP),D0
	prntLWord
	
	movea.l	#txtTrce,A1
	prntStr
	movea.l	$3E(SP),A3	;load PC from stack frame
	suba.l	#$10,A3	;subtract 16 from PC
	moveq.l	#0,D3	;clear count register
intTrcLp:	move.l	(A3,D3.l),D0	;get next longword from RAM
	prntLWord		;print longword as Hex
	movea.l	#txtSpace,A1	;get pointer to space string
	prntStr		;and print
	addq.l	#4,D3	;increment count register
	cmp.l	#$20,D3	;check for end
	ble	intTrcLp	;if less than 32, keep looping
	
;	movea.l	#txtStack,A1
;	prntStr
;	movea.l	$44(SP),A3	;get original stack pointer
;	movea.l	#initStack,A4	;get start of stack
;intStkLp:	cmp.l	A4,A3	;see we are at end of stack
;	ble	intStkEnd	;skip ahead if done
;	move.l	-(A4),D0	;get next longword from stack
;	prntLWord		;and print out
;	movea.l	#txtCRLF,A1	;print newline
;	prntStr
;	bra	intStkLp	;continue loop
;intStkEnd:	
;	movea.l	#txtEnd,A1
;	prntStr
	
	jmp	START	;warm reboot

;string storage
txtGeneric:	dc.b	'Generic Interrupt',$D,$A,0
txtBusErr:	dc.b	'Bus Error',$D,$A,0
txtAddrErr:	dc.b	'Address Error',$D,$A,0
txtIllegal:	dc.b	'Illegal Instruction',$D,$A,0
txtZeroDiv:	dc.b	'Divide by Zero',$D,$A,0
txtCHK:	dc.b	'CHK/CHK2 Instruction',$D,$A,0
txtTrapV:	dc.b	'TRAP Instruction',$D,$A,0
txtPriv:	dc.b	'Privilege Violation',$D,$A,0
txtTrace:	dc.b	'Trace',$D,$A,0
txtATrap:	dc.b	'A-Trap Instruction',$D,$A,0
txtFTrap:	dc.b	'F-Trap Instruction',$D,$A,0
txtCprcViol:	dc.b	'Coproc Protocol Err',$D,$A,0
txtFormat:	dc.b	'Format Error',$D,$A,0
txtUninit:	dc.b	'Uninitialized Int',$D,$A,0
txtSpur:	dc.b	'Spurious Interrupt',$D,$A,0
txtInt1:	dc.b	'AVEC Level 1',$D,$A,0
txtInt2:	dc.b	'AVEC Level 2',$D,$A,0
txtInt3:	dc.b	'AVEC Level 3',$D,$A,0
txtInt4:	dc.b	'AVEC Level 4',$D,$A,0
txtInt5:	dc.b	'AVEC Level 5',$D,$A,0
txtInt6:	dc.b	'AVEC Level 6',$D,$A,0
txtInt7:	dc.b	'AVEC Level 7',$D,$A,0
txtTrap0:	dc.b	'Trap 0 Instruction',$D,$A,0
txtTrap1:	dc.b	'Trap 1 Instruction',$D,$A,0
txtTrap2:	dc.b	'Trap 2 Instruction',$D,$A,0
txtTrap3:	dc.b	'Trap 3 Instruction',$D,$A,0
txtTrap4:	dc.b	'Trap 4 Instruction',$D,$A,0
txtTrap5:	dc.b	'Trap 5 Instruction',$D,$A,0
txtTrap6:	dc.b	'Trap 6 Instruction',$D,$A,0
txtTrap7:	dc.b	'Trap 7 Instruction',$D,$A,0
txtTrap8:	dc.b	'Trap 8 Instruction',$D,$A,0
txtTrap9:	dc.b	'Trap 9 Instruction',$D,$A,0
txtTrapA:	dc.b	'Trap A Instruction',$D,$A,0
txtTrapB:	dc.b	'Trap B Instruction',$D,$A,0
txtTrapC:	dc.b	'Trap C Instruction',$D,$A,0
txtTrapD:	dc.b	'Trap D Instruction',$D,$A,0
txtTrapE:	dc.b	'Trap E Instruction',$D,$A,0
txtTrapF:	dc.b	'Trap F Instruction',$D,$A,0
txtFPUunord:	dc.b	'FPU Unordered Cond',$D,$A,0
txtFPUinxct:	dc.b	'FPU Inexact Result',$D,$A,0
txtFPUdiv0:	dc.b	'FPU Divide by Zero',$D,$A,0
txtFPUunder:	dc.b	'FPU Underflow',$D,$A,0
txtFPUoperr:	dc.b	'FPU Operand Error',$D,$A,0
txtFPUover:	dc.b	'FPU Overflow',$D,$A,0
txtFPUnan:	dc.b	'FPU Not a Number',$D,$A,0
txtMMUconfig:	dc.b	'MMU Config Error',$D,$A,0
txt68851:	dc.b	'MC68851 Error',$D,$A,0

txtPC	dc.b	'PC: $',0
txtSR	dc.b	' SR: $',0
txtA7	dc.b	$D,$A,'A7: $',0
txtA6	dc.b	' A6: $',0
txtA5	dc.b	' A5: $',0
txtA4	dc.b	' A4: $',0
txtA3	dc.b	$D,$A,'A3: $',0
txtA2	dc.b	' A2: $',0
txtA1	dc.b	' A1: $',0
txtA0	dc.b	' A0: $',0
txtD7	dc.b	$D,$A,'D7: $',0
txtD6	dc.b	' D6: $',0
txtD5	dc.b	' D5: $',0
txtD4	dc.b	' D4: $',0
txtD3	dc.b	$D,$A,'D3: $',0
txtD2	dc.b	' D2: $',0
txtD1	dc.b	' D1: $',0
txtD0	dc.b	' D0: $',0
txtTrce	dc.b	$D,$A,'Trace: ',0
txtStack	dc.b	$D,$A,'Stack: ',$D,$A,0
txtEnd	dc.b	$D,$A,'Rebooting ...',$D,$A,0
txtSpace	dc.b	' ',0
txtCRLF	dc.b	$D,$A,0

;interrupt vector string pointer table
tblIntTxt:	dc.l	txtGeneric
	dc.l	txtGeneric
	dc.l	txtBusErr
	dc.l	txtAddrErr
	dc.l	txtIllegal
	dc.l	txtZeroDiv
	dc.l	txtCHK
	dc.l	txtTrapV
	dc.l	txtPriv
	dc.l	txtTrace
	dc.l	txtATrap
	dc.l	txtFTrap
	dc.l	txtGeneric
	dc.l	txtCprcViol
	dc.l	txtFormat
	dc.l	txtUninit
	dcb.l	8,txtGeneric

	dc.l	txtSpur
	dc.l	txtInt1
	dc.l	txtInt2
	dc.l	txtInt3
	dc.l	txtInt4
	dc.l	txtInt5
	dc.l	txtInt6
	dc.l	txtInt7
	dc.l	txtTrap0
	dc.l	txtTrap1
	dc.l	txtTrap2
	dc.l	txtTrap3
	dc.l	txtTrap4
	dc.l	txtTrap5
	dc.l	txtTrap6
	dc.l	txtTrap7
	dc.l	txtTrap8
	dc.l	txtTrap9
	dc.l	txtTrapA
	dc.l	txtTrapB
	dc.l	txtTrapC
	dc.l	txtTrapD
	dc.l	txtTrapE
	dc.l	txtTrapF
	dc.l	txtFPUunord
	dc.l	txtFPUinxct
	dc.l	txtFPUdiv0
	dc.l	txtFPUunder
	dc.l	txtFPUoperr
	dc.l	txtFPUover
	dc.l	txtFPUnan
	dc.l	txtGeneric

	dc.l	txtMMUconfig
	dcb.l	2,txt68851
	dcb.l	197,txtGeneric

;***********************************************************
	org	romSect1
START:			;now we get on to actual code
	movea.l	#ramTop128+1,SP	;warm boot reset stack pointer
initACIA:
	;movea.l	#aciaBase,A0	;get ACIA address in A0
	;move.b	#$1E,$C(A0)	;set ACIA for 8bit,1stop,9600bps
	;move.b	#$0A,$8(A0)	;set ACIA for no parity, no interrupts
	move.b	#$03,aciaComm	;soft reset ACIA before initializing
	move.b	#$15,aciaComm	;set ACIA for 38400,8N1,no interrupts
	movea.l	#strAcia1,A1	;get address of ACIA init string
	prntStr		;print ACIA init string

copyBasic:
	movea.l	#strBasCpy1,A1	;get address of header string
	prntStr		;print loading basic string
	movea.l	#romSect2,A0	;get base address of BASIC for copy origin
	movea.l	#ramBot,A1	;get base address of RAM for copy destination
	move.l	#$d4b,D0	;count of long words to copy
.copyLoop:	move.l	(A0)+,(A1)+	;copy longword & increment addresses
	dbra	D0,.copyLoop	;copy until count expired
	movea.l	#strBasCpy2,A1	;get address of complete string
	prntStr		;print load complete string
verifyBasic:
	movea.l	#romSect2,A0	;get base address of BASIC original
	movea.l	#ramBot,A1	;get base address of BASIC copy
	move.l	#$d4b,D0	;count of long words to verify
.verLoop:	move.l	(A0)+,D1	;get long word from original
	move.l	(A1)+,D2	;get long word from copy
	cmp.l	D1,D2	;compare
	bne	vErrrr	;if not equal, report error
	dbra	D0,.verLoop	;continue loop until count expired
.verGood:	movea.l	#strBasCpy3,A1	;get address of verify good string
	prntStr		;print verify good string
	jmp	ramBot	;run BASIC
vErrrr:	move.l	A0,A5	;save copies of our registers
	move.l	A1,A6	;since we obviously can't trust RAM
	move.l	D1,D5
	move.l	D2,D6
	movea.l	#strBasCpy4,A1	;get address of verify failed string
	prntStr		;print verify failed string
	move.l	A6,D0	;get failed RAM address
	prntLWord		;print longword macro
	movea.l	#strBasCpy5,A1	;get next string address
	prntStr
	move.l	D5,D0	;get value read from ROM
	prntLWord		;print value
	movea.l	#strBasCpy6,A1	;get next string address
	prntStr
	move.l	D6,D0	;get value read from RAM
	prntLWord
	move.b	#$0D,D0
	prntChr
	move.b	#$0A,D0
	prntChr
	stop	#$2700
errLp:	nop
	bsr.s	errLp


;***********************************************************

strAcia1:	dc.b	'ACIA Ready',$0D,$0A,0
strBasCpy1:	dc.b	'Loading Basic...',$0D,$0A,0
strBasCpy2:	dc.b	'Loaded. Verifying...',$0D,$0A,0
strBasCpy3:	dc.b	'Load success. Starting...',$0D,$0A,0
strBasCpy4:	dc.b	'Verify failed at $',0
strBasCpy5:	dc.b	'. ROM: $',0
strBasCpy6:	dc.b	', RAM: $',0

	END	START