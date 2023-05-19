
    include "addresses.x68"
    include "macros.x68"

    ORG 0
    include "vectors.x68"

;******************************************************************************
; Startup initialization code
;
START:            ;now we get on to actual code
    movea.l #initStack,SP       ;warm boot reset stack pointer

    ; set up COM 0
    initCOM0
    prntStrByName   strCOM0     ; print init complete string

    bra     memTest1

strCOM0 dc.b    CR,LF,"COM0 Init Complete.",CR,LF,0

    even

;******************************************************************************
; First memory test - longword write & verify
;
memTest1:
    prntStrByName   strMemTest1start
    lea     ramBot,A0           ; get pointer to first RAM address
    lea     memTest1pat(PC),A6  ; get pointer to test patterns table
    move.b  memTest1patCnt(PC),D7 ; get number of patterns to test

memTest1lp:
    move.l  (A6)+,D6            ; get test pattern
    move.l  D6,(A0)             ; write test pattern
    nop8                        ; clear the bus
    move.l  (A0),D5             ; read back pattern
    cmp.l   D5,D6               ; compare to test pattern
    bne     memTest1err         ; report error
memTest1errRet:
    dbra    D7,memTest1lp       ; continue testing until complete

    prntStrByName   strMemTest1done
    bra     memTest2            ; jump ahead to next test

memTest1err:                    ; print error results
    prntStrByName   strMemTest1err1
    move.l D6,D0
    prntLWord
    prntStrByName   strMemTest1err2
    move.l D5,D0
    prntLWord
    prntNewLine
    bra     memTest1errRet      ; return to test

strMemTest1start:   dc.b    "Starting memory test 1 (confirm longword read/write)",CR,LF,0
strMemTest1done:    dc.b    "Memory test 1 complete",CR,LF,0
strMemTest1err1:    dc.b    "Mem Test 1 Error. Expected: $",0
strMemTest1err2:    dc.b    " Read: $",0

memTest1patCnt:     dc.b    3
    even
memTest1pat:        dc.l    $00000000
                    dc.l    $ffffffff
                    dc.l    $55555555
                    dc.l    $aaaaaaaa
    even

;******************************************************************************
; Second memory test - sequential byte writes
;
memTest2:
    prntStrByName   strMemTest2start
    lea     ramBot,A0           ; get pointer to first RAM address
    movea.l A0,A6               ; make a copy of it
    move.l  memTest2pat(PC),D7  ; get test pattern

    rol.l   #8,D7               ; rotate first byte into position
    move.b  D7,(A0)+            ; write first pattern byte
    rol.l   #8,D7               ; rotate next byte into position
    move.b  D7,(A0)+            ; write second pattern byte
    rol.l   #8,D7               ; rotate next byte into position
    move.b  D7,(A0)+            ; write third pattern byte
    rol.l   #8,D7               ; rotate next byte into position
    move.b  D7,(A0)+            ; write fourth pattern byte
    move.l  (A6),D6             ; read back pattern that was written
    cmp.l   D6,D7               ; check if patterns match
    bne     memTest2err         ; error if no match
memTest2errRet:
    prntStrByName   strMemTest2done
    bra     memTest3

memTest2err:                    ; print error results
    prntStrByName   strMemTest2err1
    move.l D7,D0
    prntLWord
    prntStrByName   strMemTest2err2
    move.l D6,D0
    prntLWord
    prntNewLine
    bra     memTest2errRet      ; return to test

memTest2pat:    dc.l    $55aa1188

strMemTest2start:   dc.b    "Starting memory test 2 (write sequential bytes)",CR,LF,0
strMemTest2done:    dc.b    "Memory test 2 complete",CR,LF,0
strMemTest2err1:    dc.b    "Mem Test 2 Error. Expected: $",0
strMemTest2err2:    dc.b    " Read: $",0

    even

;******************************************************************************
; Third memory test - SIMM 0 size check
;
memTest3:
    prntStrByName   strMemTest3start
    ; first thing we need to do here is set the memory controller for its
    ; largest supported SIMM size
    prntStrByName   strMemTest3str1
    move.l  #dramCtrlPort,D7    ; get base address for DRAM control register
    ori.l   #$0f00,D7           ; set ram size bits

    move.l  D7,D0
    prntLWord

    movea.l D7,A0               ; copy to pointer
    move.l  D7,(A0)             ; write to that address to configure controller
    prntStrByName   strMemTest3str2

    ; now try to find how big the first SIMM is by clearing address 0, 
    ; writing a pattern to increasingly larger addresses, until address 0
    ; is no longer clear. Starting from address 4, this will get us the
    ; installed SIMM's column size.  
    lea     ramBot,A0           ; get pointer to base of RAM
    move.l  A0,D7               ; copy to D7 so we can manipulate it
    addq.l  #4,D7               ; set starting address
    move.l  #0,(A0)             ; clear address 0
memTest3lp1:
    movea.l D7,A1               ; copy working register to pointer
    move.l  D7,(A1)             ; copy pattern to pointer address
    cmpi.l  #0,(A0)             ; check if address 0 is still clear
    bne     memTest3colSiz      ; if not clear, we've found column size
    lsl.l   #1,D7               ; shift test address
    cmp.l   #$4000,D7           ; check if we're at the largest supported
    blt     memTest3lp1         ; if not, then keep testing
memTest3colSiz:
    lsr.l   #1,D7               ; shift pattern backwards by 1 to find where 
                                ; we stopped, then print results
    prntStrByName   strMemTest3col1
    move.l  D7,D0
    prntLWord
    prntNewLine
    ; at this point, D7 should be one of $2000, $1000, $0800, or $0400
    ; we'll need to conver this into $11, $10, $01, or $00, respectively.
    ; our else condition will be $00.
    cmpi.l  #$2000,D7           ;
    beq     memTest3colSiz11    ;
    cmpi.l  #$1000,D7           ;
    beq     memTest3colSiz10    ;
    cmpi.l  #$0800,D7           ;
    beq     memTest3colSiz01    ;
memTest3colSize00:
    moveq.l #0,D6               ; colSize is 00
    move.l  #$0400,D7           ; handle else case
    bra     memTest3findRowsiz  ;
memTest3colSiz01:
    moveq.l #1,D6               ; colSize is 01
    bra     memTest3findRowsiz  ;
memTest3colSiz10:
    moveq.l #2,D6               ; colSize is 10
    bra     memTest3findRowsiz  ;
memTest3colSiz11:
    moveq.l #3,D6               ; colSize is 11

memTest3findRowsiz:
; now we need to configure the DRAM controller for the column size we found, 
; then start the test to find the row size for the currently installed SIMM0
    prntStrByName   strMemTest3col2
    move.l  D6,D5               ; save a copy of colSize parameter
    ori.l   #$C,D6              ; set row bits
    lsl.l   #8,D6               ; shift size into position
    ori.l   #dramCtrlPort,D6    ; set address bits
    movea.l D6,A0               ; convert to pointer
    move.l  D6,(A0)             ; set DRAM control register
    move.l  D5,D6               ; restore colSize parameter
    prntStrByName   strMemTest3str2
; now let's return to D7, which has the highest available column bit set.
; shift it left once to get the starting row size, then keep shifting until we
; find the highest available row size
    eor.l   D0,D0               ; clear D0
    movea.l D0,A0               ; get pointer to address 0
    move.l  D0,(A0)             ; make sure address 0 is clear
    lsl.l   #1,D7               ; get first row address
memTest3lp2:
    movea.l D7,A1               ; convert to pointer
    move.l  D7,(A1)             ; write pattern to test address
    cmpi.l  #0,(A0)             ; confirm if address 0 is still clear
    bne     memTest3RowSiz      ; not clear, we've found the end
    lsl.l   #1,D7               ; get next row address
    cmp.l   #$04000000,D7       ; check if we're past the limit
    blt     memTest3lp2         ; if not, then continue loop
memTest3RowSiz:
    lsr.l   #1,D7               ; shift pattern backwards by 1 to get the
                                ; highest valid row address bit, then print
                                ; the results
    prntStrByName   strMemTest3row1
    move.l  D7,D0               ;
    prntLWord                   ;
    prntNewLine                 ;
    ; ok, this one is going to be a little harder than the column size was.
    ; the top row bit will be somewhere between A19 & A25, depending on where
    ; we ended up with the column size and how large is the row size we found.

    ; for now, I'm just going to stop here
    bra     memTestEnd

strMemTest3start:   dc.b    "Starting memory test 3 (SIMM0 size probe)",CR,LF,0
strMemTest3str1:    dc.b    "Mem Test 3 - Configuring DRAM controller for 12-bit ROW & 12-bit COL ... ",0
strMemTest3str2:    dc.b    " Done.",CR,LF,0
strMemTest3col1:    dc.b    "Mem Test 3 - Found highest SIMM0 column bit: ",0
strMemTest3col2:    dc.b    "Mem Test 3 - Configuring DRAM controller for new column size ... ",0
strMemTest3row1:    dc.b    "Mem Test 3 - Found highest SIMM1 row bit: ",0
    even

memTestEnd:
    prntStrByName   strEnd
endLoop:
    bra     endLoop

strEnd:             dc.b    "End of tests. Halting.",CR,LF,0