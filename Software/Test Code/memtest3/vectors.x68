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