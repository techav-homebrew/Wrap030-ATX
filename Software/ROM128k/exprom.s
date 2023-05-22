|******************************************************************************
|* Wrap030 TSMON Expansion ROM
|* techav
|* 2021-12-26
|******************************************************************************
|* Provides additional commands for TSMON ROM monitor
|*****************************************************************************/

    .include "TSMON_Constants.INC"
    .include "TSMON_FAT.INC"
    .include "macros.inc"

|    .equ ROMBASIC, romSector1       | address for BASIC in ROM
|    .equ RAMBASIC, ramBot+startHeap | above vector table & TSMON globals
|    .equ HEAPBASIC, RAMBASIC+0x4000 | above BASIC program in RAM
|    .equ SIZBASIC, 0x4000            | total size of BASIC to copy from ROM (~16kB)

|******************************************************************************
| HEADER & INITIALIZATION
|******************************************************************************
|    .org	expROM
| This is loaded by TSMON on startup to confirm an expansion ROM is installed
    .section text,"ax"
    .global EXTROM
EXTROM:	
    DC.L	0x524f4d32	        |Expansion ROM identification ('ROM2')
    DC.L	0

    .even
| This is called by TSMON on startup to allow the expansion ROM to initialize
| anything it may need to initialize on startup.
RM2INIT:	
    lea	    DATA,%a6	        | A6 points to RAM heap
    lea	    UCOM,%a5	        | A5 points to User Command Table
    move.l  %a5,%a6@(UTAB)	    | Copy User Com Table ptr
    lea	    %pc@(sBNR),%a4      | Get pointer to banner string
    callSYS trapPutString
    callSYS trapNewLine

| Check if video installed & intialize
|    bsr     vidInit             | initialize video

| Check if FPU installed
|    BSR     ucFPUCHK

| Enable L1 cache
    BSR     ucCEnable           | enable cache by default

| Return to monitor
    lea     %pc@(sROM2end),%a4  | get final banner message pointer
    callSYS trapPutString       | print it
    callSYS trapNewLine         | and finish with a newline
    RTS

|User Command Table
UCOM:	
    DC.B	4,4
    .ascii "HELP"
    DC.L	ucHELP
    DC.B	6,3
    .ascii "BASIC "
    DC.L	ucLoadBasic
    DC.B    8,3
    .ascii "CENABLE "
    DC.L    ucCEnable
    DC.B    8,4
    .ascii "CDISABLE"
    DC.L    ucCDisable
    DC.b    4,4
    .ascii "CHKD"
    DC.l    ucCHKD
    DC.B    6,4
    .ascii "SECTOR"
    dc.L    ucSECT
    dc.B    6,3
    .ascii "FPUCHK"
    dc.L    ucFPUCHK
    dc.B    4,4
    .ascii "BOOT"
    dc.L    ucBOOT
    DC.B	0,0
|String Constants
sBNR:	.ascii "Initializing ROM 2\0\0"
sROM2end:   .ascii "ROM2 Init Complete.\0"

    .even

|******************************************************************************
| VIDEO INITIALIZATION
|******************************************************************************
vidInit:
    eor.b   %d0,%d0                     | clear D0
    lea     vidReg,%a0                  | get pointer to settings register
    move.l  0x8,%sp@-                   | save BERR vector
    move.l  #vidVect,0x8                | load temporary BERR vector
    move.b  %d0,%a0@                    | try applying video settings: $00
                                        | ouput enabled, Mode 0, buffer 0
    cmpi.b  #0,%d0                      | is D0 still clear or did we BERR?
    bne     vidNone                     | skip video init if not installed
    move.l  %sp@+,0x8                   | restore BERR vector

| Initialize video
    lea     %pc@(sVIDstart),%a4         | get pointer to VRAM init start message
    callSYS trapPutString               | and print it
    lea     vidBase,%a0                 | get pointer to top of VRAM
    move.l  #0x0FFFE,%d0                | set up loop counter
    EOR.B   %d1,%d1                     | clear a register to use for clearing VRAM
vidInitLp:
    MOVE.B  %d1,%a0@(0,%d0.L)           |clear VRAM byte
    MOVE.B  %d1,%a0@(0,%d0.L)           |make sure it is clear
    DBRA    %d0,vidInitLp               |loop until complete

    lea     %pc@(sVIDend),%a4           | get pointer to VRAM init end message
    callSYS trapPutString               | and print it.
    callSYS trapNewLine

    rts

vidNone:
    move.l  %sp@+,0x8                   | restore BERR vector
    lea     %pc@(sVIDnone),%a4          | load pointer to no video string
    callSYS trapPutString               | print string
    rts

vidVect:
    moveq   #1,%d0                      | set no video flag
    rte                                 | return from exception

sVIDnone:   .ascii  "Video not installed.\0"
sVIDstart:  .ascii "Initializing Video Memory ... \0"
sVIDend:    .ascii "Done.\0"
    .even

|******************************************************************************
| FPU FUNCTIONS
|******************************************************************************
| check for presence of FPU
| RETURNS:
|   D0 - 1: FPU present| 0: FPU not present
fpuCheck:
    move.l  0x8,%sp@-                   | save bus error vector
    move.l  0x34,%sp@-                  | save coprocessor protocol violation vector
    move.l  #fpuVect,0x8                | load temporary vectors
    move.l  #fpuVect,0x34
    move.b  #1,%d0                      | set flag
    fnop                                | test an FPU instruction
    move.l  %sp@+,0x34                  | restore vectors
    move.l  %sp@+,0x8
    rts                                 | and return
fpuVect:
    move.b  #0,%d0                      | clear flag
    rte

ucFPUCHK:
| Check FPU status
    BSR     fpuCheck                    |Check if FPU is installed
    CMP.b   #0,%d0                      |Check returned flag
    BNE     .initFPUy                   |
    lea     %pc@(sFPUn),%a4             |Get pointer to FPU not installed string
    BRA     .initFPUmsg                 |Jump ahead to print string
.initFPUy:
    lea     %pc@(sFPUy),%a4             |Get pointer to FPU installed string
.initFPUmsg:
    callSYS trapPutString               |Print FPU status string
    callSYS trapNewLine
    rts

sFPUy:  .ascii "FPU Installed.\0\0"
sFPUn:  .ascii "FPU Not Installed.\0\0"

    .even

|******************************************************************************
| HELP FUNCTION
|******************************************************************************
| This is our Help function which prints out a list of commands supported by 
| TSMON and this expansion ROM
ucHELP:	
    lea	    %pc@(sHELP),%a4	            | Get pointer to help text string
    callSYS trapPutString               | print it
    callSYS trapGetChar                 | wait for user
    lea     %pc@(sHELP2),%a4            | Get pointer to HELP2 string
    callSYS trapPutString               | print it
    callSYS trapNewLine
    RTS

sHELP:	
    .ascii "Available Commands:\r\n"
    .ascii "JUMP <ADDRESS>                 - Run from address\r\n"
    .ascii "MEMory <ADDRESS>               - Display & Edit memory\r\n"
    .ascii "LOAD <SRECORD>                 - Load SRecord into memory\r\n"
    .ascii "DUMP <START> <END> [<STRING>]  - Dump SRecord to aux\r\n"
    .ascii "TRAN                           - Transparent mode\r\n"
    .ascii "NOBR <ADDRESS>                 - Remove breakpoint\r\n"
    .ascii "DISP                           - Print register contents\r\n"
    .ascii "GO <ADDRESS>                   - Run from address w/Registers\r\n"
    .ascii "BRGT <ADDRESS>                 - Add breakpoint to table\r\n"
    .ascii "PLAN                           - Insert breakpoints\r\n"
    .ascii "KILL                           - Remove breakpoints\r\n"
    .ascii "GB [<ADDRESS>]                 - Set breakpoints & go\r\n"
    .ascii "REG <REG> <VALUE>              - Set register contents\r\n"
    .ascii "--press any key to continue--\r\n\0"
sHELP2:
    .ascii "--EXPANSION ROM--\r\n"
    .ascii "HELP                           - Print this message\r\n"
    .ascii "BASic                          - Load BASIC\r\n"
    .ascii "CENable                        - Enable L1 cache\r\n"
    .ascii "CDISable                       - Disable L1 cache\r\n"
    .ascii "CHKD                           - Check if disk inserted\r\n"
    .ascii "SECTor <ADDRESS>               - Print disk sector contents\r\n"
    .ascii "FPUchk                         - Check if FPU is installed\r\n"
    .ascii "BOOT                           - Execute boot block from disk\r\n"
    DC.B	0,0

    .even

|******************************************************************************
| BASIC LOADER
|******************************************************************************
| This function will load BASIC from ROM into RAM and jump to it.
ucLoadBasic:                | load BASIC into RAM and execute
    MOVEM.L %a0-%a6/%d0-%d7,%a7@-   | save all registers in case we make it back here
    .ifdef  debug
    debugPrint '0'
    .endif
    lea     %pc@(sBAS1a),%a4    | get pointer to header text string
    callSYS trapPutString
.startCopy:
    .ifdef  debug
    debugPrint '1'
    .endif
    lea     ROMBASIC,%a0                | get pointer to BASIC in ROM
    move.l  %a0,%d0                     | copy pointer for printing
    callSYS trapPutHexLong              | print pointer
    lea     %pc@(sBAS1b),%a4            | get pointer to next header string
    callSYS trapPutString               | print string
    lea     RAMBASIC,%a1                | get pointer to RAM above vector table
    move.l  %a1,%d0                     | copy pointer for printing
    callSYS trapPutHexLong              | print pointer
    lea     %pc@(sBAS1c),%a4            | get pointer to final header string
    callSYS trapPutString               | print string
    .ifdef  debug
    debugPrint '2'
    .endif
    lea     ROMBASIC,%a0                | re-load pointers because I dont know
    lea     RAMBASIC,%a1                | if they get clobbered by string print
    .ifdef  debug
    debugPrint '3'
    .endif
|    move.l  #(SIZBASIC>>2),%d0         | number of longwords to copy 
    move.l  #SIZBASIC,%d0               | number of bytes to copy
    .ifdef  debug
    movem.l %a0-%a6/%d0-%d7,%sp@-
    debugPrint '4'
    debugPrint '$'
    callSYS trapPutHexLong
    debugPrint 0xd
    debugPrint 0xa
    movem.l %sp@+,%a0-%a6/%d0-%d7
    .endif
    lsr.l   #2,%d0                      | number of longwords to copy
                                        | (NEED BETTER WAY TO GET THIS NUMBER)
    .ifdef  debug
    movem.l %a0-%a6/%d0-%d7,%sp@-
    debugPrint '5'
    debugPrint '$'
    callSYS trapPutHexLong
    debugPrint 0xd
    debugPrint 0xa
    movem.l %sp@+,%a0-%a6/%d0-%d7
    .endif
copyLoop:
    move.l  %a0@+,%a1@+                 | copy BASIC into RAM, one Longword at a time
    dbra    %d0,copyLoop                | keep copying until finished
    .ifdef  debug
    debugPrint '6'
    .endif
    lea     %pc@(sBAS2),%a4             | get pointer to verifying string
    .ifdef  debug
    debugPrint '7'
    .endif
    callSYS trapPutString               | print verifying string
.startVerify:
    .ifdef  debug
    debugPrint '8'
    .endif
    lea     ROMBASIC,%a0
    lea     RAMBASIC,%a1
    move.l  #SIZBASIC,%d0               | size of BASIC provided by linker
    lsr.l   #2,%d0
verifyLoop:
    move.l  %a0@+,%d1
    move.l  %a1@+,%d2
    CMP.L   %d1,%d2
    bne     vErrrr
    dbra    %d0,verifyLoop
.verifyGood:
    .ifdef  debug
    debugPrint '9'
    .endif
    lea     %pc@(sBAS3a),%a4            | get pointer to verify good string
    callSYS trapPutString
    move.l  startBasic,%d0              | start address provided by linker
    andi.l  #0x0000FFFF,%d0             | we only need the low word of this address
    lea     RAMBASIC,%a1                | pointer to start of BASIC in RAM
    lea     %a1@(0,%d0.l),%a1           | pointer to start of BASIC program
| we need base heap address in A0 and free RAM in D0
    lea     HEAPBASIC,%a0               | get bottom free memory after BASIC program
    move.l  %sp,%d0                     | get current stack pointer (top of free RAM)
    SUBI.L  #4,%d0                      | make room for our return address
    SUB.L   %a0,%d0                     | get current RAM free
| print some helpful information about what we are doing
    move.l  %a1,%sp@-                   | first, save the three parameters we need
    move.l  %d0,%sp@-
    move.l  %a0,%sp@-
    move.l  %sp@,%d0                    | get heap pointer
    callSYS trapPutHexLong              | print the heap pointer
    lea     %pc@(sBAS3b),%a4            | get the next header string
    callSYS trapPutString               | print it too
    move.l  %sp@(4),%d0                 | get the free memory size
    callSYS trapPutHexLong              | print it
    lea     %pc@(sBAS3c),%a4            | get the next header string
    callSYS trapPutString               | print it as well
    move.l  %sp@(8),%d0                 | finally get the program pointer
    callSYS trapPutHexLong              | print it
    lea     %pc@(sBAS3d),%a4            | now the last header string
    callSYS trapPutString               | print it
    move.l  %sp@+,%a0                   | restore the saved parameters
    move.l  %sp@+,%d0
    move.l  %sp@+,%a1
| enough printing stuff, jump to BASIC already
    jsr     %a1@                        | jump to BASIC in RAM
    MOVEM.L %a7@+,%a0-%a6/%d0-%d7       | by some miracle we have come back.
    RTS                                 | Restore registers and return

vErrrr:
| BASIC in RAM does not match BASIC in ROM
    lea     %pc@(sBASerr),%a4           | get pointer to error string
    callSYS trapPutString
    MOVEM.L %a7@+,%a0-%a7/%d0-%d7       | restore saved registers
    RTS                                 | and return to TSMON

sBAS1a:
    .ascii "Copying BASIC from $\0"
sBAS1b:
    .ascii " to $\0"
sBAS1c:
    .ascii " ... \0"
sBAS3a:
    .ascii "OK.\r\n"
    .ascii "Heap Pointer: $\0"
sBAS3b:
    .ascii ".\r\nFree Mem: $\0"
sBAS3c:
    .ascii ".\r\nBASIC Pointer: $\0"
sBAS3d:
    .ascii ".\r\nStarting BASIC ... \r\n\0"

|sBAS1:
|    .ascii "Loading BASIC ... \0\0"
sBAS2:
    .ascii "OK.\r\nVerifying BASIC ... \0\0"
|sBAS3:
|    .ascii "OK.\r\nStarting BASIC ... \r\n\0\0"
sBASerr:
    .ascii "Failed.\r\nUnable to run BASIC.\r\n\0\0"

    .even

|******************************************************************************
| 68030 CACHE FUNCTIONS
|******************************************************************************
| Enable 68030 cache
ucCEnable:
    MOVEM.L %a4/%d0,%a7@-     | save working registers
    move.l  #0x00000101,%d0    | enable data & instruction cache
|    DC.L    $4e7b0002       | movec D0,CACR
    movec   %d0,%cacr
    lea     %pc@(sCEN),%a4     | get pointer to feedback string
    callSYS trapPutString
    callSYS trapNewLine
    MOVEM.L %a7@+,%d0/%a4     | restore working registers
    RTS

| Disable 68030 cache
ucCDisable:
    MOVEM.L %a4/%d0,%a7@-     | save working registers
    EOR.L   %d0,%d0           | disable data & instruction cache
|    DC.L    $4e7b0002       | movec %d0,CACR
    movec   %d0,%cacr
    lea     %pc@(sCDIS),%a4    | get pointer to feedback string
    callSYS trapPutString
    callSYS trapNewLine
    MOVEM.L %a7@+,%d0/%a4     | restore working registers
    RTS

sCEN:
    .ascii "CPU L1 Cache Enabled.\0\0"
sCDIS:
    .ascii "CPU L1 Cache Disabled.\0\0"

    .even

|******************************************************************************
| IDE+FAT DISK FUNCTIONS
|******************************************************************************

| check for disk presence
| RETURNS:
|   D0 - 1: disk present| 0: no disk present
dskChk:
    lea     ideLBAHHRW,%a0   | get LBA HH address
    move.b  #0xE0,%a0@       | set disk to LBA mode
    move.b  %a0@,%d0         | read back set value to compare
    cmp.b   #0xE0,%d0         | make sure it matches
    bne     .dskChkNo       | branch if no disk
    move.b  #1,%d0           | return 1 if disk present
    rts                     | 
.dskChkNo:
    move.b  #0,%d0           | return 0 if no disk present
    rts

| read one sector from disk
| PARAMETERS:
|   A0 - LBA
|   A1 - read buffer
| RETURNS:
|   D0 - 1: success| 0: error
dskRdSect:
    movem.l %a0-%a2/%a4/%d1-%d3,%sp@-
    bsr     dskChk              | check if disk present
    cmp.b   #1,%d0               |
    bne     .dskRdErr1          | jump to error if no disk
    move.l  %a0,%d0               | copy provided LBA to D0
    or.l    #0x40000000,%d0       | set flag to use LBA addressing
    move.l  #ideBase,%a2         | get base IDE address
    move.b  %d0,%a2@(ideLBALLRW)   | set LBA LL byte
    lsr.l   #8,%d0               | shift next byte into position
    move.b  %d0,%a2@(ideLBALHRW)   | set LBA LH byte
    lsr.l   #8,%d0               | shift next byte into position
    move.b  %d0,%a2@(ideLBAHLRW)   | set LBA HL byte
    lsr.l   #8,%d0               | shift last byte into position
    move.b  %d0,%a2@(ideLBAHHRW)   | set LBA HH byte & flag
    move.b  #1,%a2@(ideSectorCountRW) | tell disk to transfer 1 sector only
    move.b  #ideCmdReadSect,%a2@(ideCommandWO)    | send Read Sector command
    move.w  #0xFF,%d0             | set loop counter to 256 words
.dskRdLoop:
    moveq   #0,%d2               | clear error counter
.dskRdLp1:
    move.b  %a2@(ideStatusRO),%d1  | check disk status
    btst    #7,%d1               | check disk busy bit
    beq     .dskRdLp2           | if clear, go read next word
    addi.b  #1,%d2               | increment error counter
    tst.b   %d2                  | test if error counter has overflowed to 0
    beq     .dskRdErr2          | jump to error for read timeout
    bra     .dskRdLp1           | keep looping if we have not timed out yet
.dskRdLp2:
    btst    #0,%d1               | check for read error
    bne     .dskRdErr3          | if error, then jump to error
    move.w  %a2@,%d3             | read word from disk
    lsl.w   #8,%d3               | byte swap to correct wiring error
    move.w  %d3,%a1@+            | save word to disk buffer
    dbra    %d0,.dskRdLoop       | keep looping until all 256 words read
    move.b  #1,%d0               | set read success flag
.dskRdEnd:
    movem.l %a7@+,%a0-%a2/%a4/%d1-%d3    | restore working registers
    rts                         | and return
.dskRdErr1:
    lea     %pc@(sCHKDn),%a4       | load pointer to no disk error string
    callSYS trapPutString                 | print error message
    move.b  #0,%d0               | set error flag
    bra     .dskRdEnd           | jump to end
.dskRdErr2:
    move.b  #ideCmdNOP,%a2@(ideCommandWO) | send disk NOP command
    lea     %pc@(sDSKRDerr),%a4    | load pointer to disk read error string
    callSYS trapPutString                 | print error message
    move.b  #0,%d0               | set error flag
    bra     .dskRdEnd           | jump to end
.dskRdErr3:
    move.b  %d1,%d0               | we have an actual error to look up
    bsr     dskErr              | jump to disk error handler
    bra     .dskRdEnd           | jump to end

| check disk error and print helpful message
| PARAMETERS
|   D0 - IDE error register
dskErr:
    btst    #7,%d0
    beq     .dskErr6
    lea     %pc@(sDSKerr7),%a4     | get address of error message
    bra     .dskErrEnd          | and jump to end
.dskErr6:
    btst    #6,%d0
    beq     .dskErr5
    lea     %pc@(sDSKerr6),%a4     | get address of error message
    bra     .dskErrEnd          | and jump to end
.dskErr5:
    btst    #5,%d0
    beq     .dskErr4
    lea     %pc@(sDSKerr5),%a4     | get address of error message
    bra     .dskErrEnd          | and jump to end
.dskErr4:
    btst    #4,%d0
    beq     .dskErr3
    lea     %pc@(sDSKerr4),%a4     | get address of error message
    bra     .dskErrEnd          | and jump to end
.dskErr3:
    btst    #3,%d0
    beq     .dskErr2
    lea     %pc@(sDSKerr3),%a4     | get address of error message
    bra     .dskErrEnd          | and jump to end
.dskErr2:
    btst    #2,%d0
    beq     .dskErr1
    lea     %pc@(sDSKerr2),%a4     | get address of error message
    bra     .dskErrEnd          | and jump to end
.dskErr1:
    btst    #1,%d0
    beq     .dskErr0
    lea     %pc@(sDSKerr1),%a4     | get address of error message
    bra     .dskErrEnd          | and jump to end
.dskErr0:
    btst    #0,%d0
    beq     .dskErrN
    lea     %pc@(sDSKerr0),%a4     | get address of error message
    bra     .dskErrEnd          | and jump to end
.dskErrN:
    lea     %pc@(sDSKRDerr),%a4
.dskErrEnd:
    callSYS trapPutString      | print selected error message
    rts                         | and return

sCHKDy:	    .ascii "Disk found.\r\n\0\0"
sCHKDn:	    .ascii "No disk inserted.\r\n\0\0"
sLISTsp:    .ascii "     \0\0"
sLISThead:	.ascii "File Name        Cluster  File Size\0\0"
sINPUTerr:	.ascii "Input error.\r\n\0\0"
sDSKRDerr:	.ascii "Unknown disk read error.\r\n\0\0"

sDSKerr7:	.ascii "Bad block in requested disk sector.\r\n\0\0"
sDSKerr6:	.ascii "Uncorrectable data error in disk.\r\n\0\0"
sDSKerr3:
sDSKerr5:	.ascii "Unspecified Removable Media error.\r\n\0\0"
sDSKerr4:	.ascii "Requested disk sector could not be found.\r\n\0\0"
sDSKerr2:	.ascii "Disk command aborted.\r\n\0\0"
sDSKerr1:	.ascii "Disk track 0 not found.\r\n\0\0"
sDSKerr0:	.ascii "Disk data address mark not found.\r\n\0\0"

    .even

| user command to check for disk presence
ucCHKD:
    movem.l %a0/%a4/%d0,%sp@-      | save working registers
    bsr     dskChk              | check for disk presence
    cmp.b   #0,%d0               | check if disk was found
    bne     .ucCHKD1            | branch if disk found
    lea     %pc@(sCHKDn),%a4       | load pointer to no disk found string
    bra     .ucCHKD2            | jump to end of subroutine
.ucCHKD1:
    lea     %pc@(sCHKDy),%a4       | load pointer to disk found string
.ucCHKD2:
    callSYS trapPutString      | print string
    movem.l %sp@+,%a0/%a4/%d0      | restore working registers
    rts                         | and return

| user command to print disk sector contents to console
ucSECT:
    movem.l %a0-%a1/%a4/%d0-%d3/%d7,%sp@- | save working registers
    callSYS  trapGetParam      | system call to fetch parameter 
    tst.b   %d7                  | test for input error
    bne     .ucSECTerr1         | if error, then exit
    move.l  %d0,%a0               | A0 points to sector to read
    lea     DATA,%a1
    lea     %a1@(dskBUF),%a1       | A1 points to disk buffer region of memory
    bsr     dskRdSect           | read selected disk sector
    cmp.b   #1,%d0               | check if sector read was successful
    bne     .ucSECTerr2         | if error, then exit
    move.l  %a0,%d3               | get sector number
    clr.B   %d2                  | clear line count
.ucSECT1:
    clr.b   %d1                  | clear word count
    callSYS trapNewLine        | system call to print newline
.ucSECT2:
    move.L  %d3,%d0               | copy sector to working register
    lsl.L   #1,%d0               | left shift sector by 1 to get base address
    btst    #4,%d2               | check if we are in second half of buffer
    beq     .ucSECT3            | if no, then skip ahead
    ori.l   #1,%d0               | if second half, then set low bit of base address
.ucSECT3:
    callSYS trapPutHexLong     | print base address
    move.b  %d2,%d0               | copy line count to working directory
    lsl.B   #4,%d0               | shift by 4 to get low byte of address
    callSYS trapPutHexByte     | print low byte of base address
.ucSECT4:
    callSYS trapPutSpace       | print a space
    move.w  %a1@+,%d0            | get a word from buffer
    callSYS trapPutHexWord     | print word from buffer
    addi.b  #1,%d1               | increment word counter
    cmp.B   #8,%d1               | check for end of line
    bne     .ucSECT4            | continue line
    addi.B  #1,%d2               | increment line counter
    cmp.B   #0x20,%d2             | check for end of buffer
    bne     .ucSECT1            | start new line
.ucSECTend:
    movem.l %sp@+,%a0-%a1/%a4/%d0-%d3/%d7 | restore working registers
    rts                         | and return
.ucSECTerr1:
    lea     %pc@(sINPUTerr),%a4    | load pointer to input error string
    callSYS trapPutString      | and print
    bra     .ucSECTend          | jump to end
.ucSECTerr2:
    lea     %pc@(sDSKRDerr),%a4    | load pointer to disk read error string
    callSYS trapPutString      | and print
    bra     .ucSECTend          | jump to end

| load sector 0 from disk and execute if successful
| try to gracefully handle exiting programs that return here
ucBOOT:
    movem.l %a0-%a1/%a4/%d0,%sp@-   | save working registers
    move.l  #0,%a0               | load sector 0
    lea     dskBUF,%a1           | get pointer to disk buffer
    bsr     dskRdSect           | read sector
    cmp.b   #0,%d0               | check return status
    beq.S   ucBOOTerr1          | there was a read error
    lea     dskBUF,%a1           | restore that pointer to disk buffer
    move.w  %a1@(ofsKEY),%d0       | get FAT signature
    cmp.w   #0x55AA,%d0           | check FAT signature
    bne.s   ucBOOTerr2          | unknown disk format error
    pea     %pc@(ucBOOTret)       | push return address
    jmp     %a1@(ofsBTS)          | jump to bootstrap code
ucBOOTret:
    lea     %pc@(sBOOTret),%a4     | get pointer to program exit string
ucBOOTend:
    callSYS trapPutString      | print string
    movem.l %sp@+,%a0-%a1/%a4/%d0   | restore working registers
    rts                         | return to monitor

ucBOOTerr1:                     | disk read error
    lea     %pc@(sDSKRDerr),%a4    | disk read error string
    bra     ucBOOTend           | print string & exit

ucBOOTerr2:                     | not a FAT-formatted disk
    lea     %pc@(sDSKFmtErr),%a4   | disk format error string
    bra     ucBOOTend           | print string & exit

sDSKFmtErr: .ascii "Unknown disk format.\r\n\0\0"
sBOOTret:   .ascii "\r\n\r\nProgram Exited.\r\n\0\0"

    .even

| read one sector from disk
| PARAMETERS:
|   A0 - LBA
|   A1 - read buffer
| RETURNS:
|   D0 - 1: success| 0: error
|dskRdSect:
