; attempt 2 to port from x86 to 68k
; this time with register mapping pre-planned

ImageLoadAddr:  equ $1000           ; address we'll load the program to
ramTop:         equ $001FFFFF       ; top of main memory
romBot:         equ $00200000
    include "elfhead.inc"

    ORG 0

bootProg:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Boot sector starts here ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
            dc.b    $EB,$00,$90     ; x86 jump instruction & NOP
bsOemName:  dc.b    'BootProg'      ; 0x03

;;;;;;;;;;;;;;;;;;;;;
;; BPB starts here ;;
;;;;;;;;;;;;;;;;;;;;; 

bpbBytesPerSector:      ds.w    1   ; 0x0B
bpbSectorsPerCluster:   ds.b    1   ; 0x0D
bpbReservedSectors:     ds.w    1   ; 0x0E
bpbNumberOfFATs:        ds.b    1   ; 0x10
bpbRootEntries:         ds.w    1   ; 0x11
bpbTotalSectors:        ds.w    1   ; 0x13
bpbMedia:               ds.b    1   ; 0x15
bpbSectorsPerFAT:       ds.w    1   ; 0x16
bpbSectorsPerTrack:     ds.w    1   ; 0x18
bpbHeadsPerCylinder:    ds.w    1   ; 0x1A
bpbHiddenSectors:       ds.l    1   ; 0x1C
bpbTotalSectorsBig:     ds.l    1   ; 0x20

;;;;;;;;;;;;;;;;;;;
;; BPB ends here ;;
;;;;;;;;;;;;;;;;;;;

bsDriveNumber:          ds.b    1   ; 0x24
bsUnused:               ds.b    1   ; 0x25
bsExtBootSignature:     ds.b    1   ; 0x26
bsSerialNumber:         ds.l    1   ; 0x27
bsVolumeLabel:          dc.b    "NO NAME    "   ; 0x2B
bsFileSystem:           dc.b    "FAT16   "      ; 0x36

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Boot sector code starts here ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

start:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; How much RAM is there? ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; we don't have the luxury (yet) of a system call to get total installed 
; memory, but we don't actually need this
; we're going to take over the system completely, starting a new stack,
; and copying this program to the very top of memory
; if the program we load exits back to this loader, then we'll have
; to make sure we jump to a warm start on the monitor
    move.l  #ramTop-511,SP          ; set stack pointer to 512 bytes below
                                    ; top of main memory

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reserve memory for the boot sector and its stack ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; we're going to copy this program from wherever the ROM put it to the cop of
; memory in the 512 byte space we just reserved

    move.w  #127,D2                 ; initialize loop counter for 512 bytes
                                    ; (copied as 128 long words)
    lea     bootProg(PC),A2         ; A2 points to the start of this bootloader
    move.l  SP,A1                   ; A1 points to our destination in RAM
.copyLoop:
    move.l  (A2)+,(A1)+             ; copy next longword
    dbra    D2,.copyLoop            ; continue loop until all 512 bytes copied

;;;;;;;;;;;;;;;;;;;;;;
;; Jump to the copy ;;
;;;;;;;;;;;;;;;;;;;;;;

    jmp     main(SP)        ; add offset to main function to stack pointer
                            ; and jump execution to it

main:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reserve memory for the FAT16 image (128KB max) ;;
;; and load it in its entirety                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; get Bytes per Sector value from the FAT header
    eor.l   D0,D0                   ; clear D0
    move.w  bpbBytesPerSector(PC),D0   ; fetch value
    rol.w   #8,D0                   ; word endian swap

    ; get Sectors per FAT from FAT header
    eor.l   D2,D2                   ; clear D2
    move.w  bpbSectorsPerFAT(PC),Dw ; fetch value
    rol.w   #8,D2                   ; word endian swap
    ; so now D2 is the count of sectors to copy

    ; get total number of bytes used for the FAT
    mulu.w  D2,D0                   ; stored as long in D0

    ; we need to subtract the number of bytes used for FAT from the stack
    ; pointer to allocate some space to copy the FAT to
    movea.l SP,A0                   ; get a copy of Stack Pointer
    sub.l   D0,A0                   ; subtract number of bytes from SP
    movea.l A0,SP                   ; update SP allocating buffer as frame
    move.l  D0,-(SP)                ; save buffer size to stack
    ; so now A0 is a pointer we can use to copy the FAT to

    move.l  bpbHiddenSectors(PC),D0 ; load variable
    rol.w   #8,D0                   ; longword endian swap
    swap    D0
    rol.w   #8,D0

    eor.l   D3,D3                   ; clear D3
    move.w  bpbReservedSectors(PC),D3   ; load variable
    rol.w   #8,D3                   ; word endian swap

    add.l   D3,D0                   ; add reserved sectors to hidden sectors
    ; so now D0 is the LBA we need to give to the disk to start loading from

    ; at this point, we have the values we need to call the ReadSector function
    ;   D0.L - Disk sector LBA
    ;   D2.W - Count of sectors to copy
    ;   A0.L - Disk buffer in RAM
    bsr     ReadSector

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reserve memory for the root directory  ;;
;; and load it in its entirety (16KB max) ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    move.l  D0,D1                   ; make a copy of previous LBA

; calculate how many sectors we need to load to get the entire root directory
    move.w  #32,D0                  ; 32 bytes per root entry
    move.w  bpbRootEntries(PC),D4   ; load variable
    rol.w   #8,D4                   ; word endian swap
    mulu.w  D4,D0                   ; D0 = # of bytes for root table

    move.w  bpbBytesPerSector(PC),D4    ; load variable
    rol.w   #8,D4                   ; word endian swap
    divu.w  D4,D0                   ; total sectors for root directory in D0
                                    ; this will be the count of sectors to load
                                    ; divu.w stores a longword result, with the
                                    ; high word being the quotient, and the low
                                    ; word being the remainder. We'll need to 
                                    ; check for a remainder and increment the
                                    ; quotient if not even (although there
                                    ; really shouldn't be a remainder here)
    cmpi.w  #0,D0                   ; check for remainder
    beq     .rootDirNoRem           ; skip ahead if no remainder
    swap    D0                      ; move quotient into low word
    add.w   #1,D0                   ; increment to account for remainder
    swap    D0                      ; and swap back into position
.rootDirNoRem:
    swap    D0                      ; move quotient into low word
    move.w  D0,D2                   ; D2 is count of sectors to load

; calculate the LBA for where the root directory starts on disk
; by multiplying the number of FATs (usually 2) by the total number of sectors
; consumed by a single copy of the FAT. Add this to our previous LBA.
    eor.l   D0                      ; clear D0 to start
    move.b  bpbNumberOfFATs(PC),D0  ; load byte variable
    ext.w   D0                      ; sign extend to word (really not needed..)

    move.w  bpbSectorsPerFAT(PC),D4 ; load word variable
    rol.w   #8,D4                   ; word endian swap

    mulu.w  D4,D0                   ; get total # of sectors for all FATs

    add.l   D1,D0                   ; add to previous LBA

    ; here is where the original saves the ES register with the comment:
    ;   push FAT segment (2nd parameter)
    move.l  A0,-(SP)                ; save pointer to FAT data on stack frame

    move.l  #ImageLoadAddr,A0       ; get buffer base address

    ; at this point, we have the values we need to call the ReadSector function
    ;   D0.L - Disk sector LBA
    ;   D2.W - Count of sectors to copy
    ;   A0.L - Disk buffer in RAM
    bsr     ReadSector

    ext.l   D0                      ; sign-extend sector count
    add.l   D2,D0                   ; add count of sectors just loaded to the
                                    ; LBA we just used
    movem.l D0,-(SP)                ; push LBA to stack to save for later
                                    ; (1st parameter)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Look for the COM/EXE file to load and run ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; A0.L holds the disk buffer where the root directory data was laoded
    ; A2.L will hold the pointer to the file name 
    ; D3.W will hold the number of root directory entries
    lea     ProgramName(PC),A2      ; get pointer to program file name
    move.w  bpbRootEntries(PC),D3   ; load word variable data
    rol.w   #8,D3                   ; word endian swap

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Looks for a file/dir by its name       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  A2.L  -> file name (11 chars)  ;;
;;         A0.L  -> root directory array  ;;
;;         D3.W  = number of root entries ;;
;; Output: D4.W  = cluster number         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FindName:
    moveq   #11,D2                  ; count of bytes in a file name
FindNameCycle:
    cmpi.b  #0,(A0)                 ; check for end of list
    beq.s   FindNameFailed          ; end of the root list

    movem.l A0/A2/D2,-(SP)          ; save working registers
.FindNameCheck:
    cmpm.b  (A1)+,(A0)+             ; compare filenames
    dbeq    D2,.FindNameCheck       ; keep looping while equal
    
    movem.l (SP)+,A0/A2/D2          ; restore working registers
    beq.s   FindNameFound           ; file name was a match

    add.l   #32,A0                  ; no match, increment pointer to next
                                    ; root directory entry
    subq.w  #1,D3                   ; decrement directory entry counter
    bne.s   FindNameCycle           ; check next directory entry
FindNameFailed:
    bra     ErrFind
FindNameFound:
    move.w  $1A(A0),D4              ; load cluster number
    rol.w   #8,D4                   ; word endian swap

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Load the entire file ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadNextCluster:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads a FAT16 cluster       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Inout:  A0.L -> buffer      ;;
;;         D4.W = cluster no   ;;
;; Output: D4.W = next cluster ;;
;;         A0.L -> next addr   ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadCluster:
    movea.l SP,A6                   ; copy the stack pointer, we need it

    move.w  D4,D0
    sub.w   #2,D0                   ; get the cluster number
    eor.l   D2                      ; clear register
    move.b  bpbSectorsPerCluster(PC),D2
    mulu.w  D2,D0                   ; sector number in D0
    add.l   (A6),D0                 ; add sector number to LBA that was pushed
                                    ; to the stack previously. This LBA should
                                    ; be pointing to the first data sector

    ; at this point, we have the values we need to call the ReadSector function
    ;   D0.L - Disk sector LBA
    ;   D2.W - Count of sectors to copy
    ;   A0.L - Disk buffer in RAM
    bsr     ReadSector

; so now we've read into memory all sectors from this cluster

    move.w  bpbBytesPerSector(PC),D0
    rol.w   #8,D0                   ; word endian swap
    mulu.w  D2,D0                   ; D0 = total bytes read for this cluster
    add.l   D0,A0                   ; increment buffer pointer by the number
                                    ; of bytes read, so we can start loading 
                                    ; the next cluster starting from here
    
; now we need to traverse the FAT to find the next cluster we need to read
    add.w   D4,D4                   ; D2 = cluster# * 2
    move.l  4(SP),A5                ; get pointer to FAT on stack frame
    move.w  0(D4.w,A5),D4           ; get next cluster value

ReadClusterDone:
    cmp.w   #$FFF8,D4               ; check for last cluster in chain
    bne     ReadNextCluster         ; continue if not end of file

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Parse executable header data ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; ok, at this point, we should have the entire file loaded into memory, 
; starting at the address ImageLoadAddr ($00001000)
; This is the point where the original program tries to determine if it has
; just loaded a .COM or .EXE file. We're going to use .ELF instead.

    move.l  #ImageLoadAddr,A0       ; initialize pointer to file header data

; check ELF file header
    cmpi.l  #elfMag,eIdent(A0)      ; check for 'ELF' header
    bne     loadNotELF              ; not an ELF binary
    cmpi.w  #4,eMachine(A0)         ; check if m68k binary
    bne     loadNotELF68k           ; not a 68k binary
    move.w  ePhNum(A0),D1           ; get program segment count
    cmpi.w  #0,D1                   ; make sure it's greater than 0
    beq     loadNotELFpgm           ; not an ELF program
    move.w  ePhentSize(A0),D2       ; get size of each program header entry
    ext.l   D2                      ; sign-extend to longword
    move.l  ePhoff(A0),D0           ; load base offset to program header
    move.l  #0,A4                   ; we'll use A4 to calculate the highest
                                    ; free memory address not used.
.loadELFpgmSeg:
    cmpi.w  #0,D1                   ; have we checked all segments?
    beq     runElfPgm               ; looks like we have, go run the program
    ; now we need to check the program segment type
    cmpi.l  #ptLoad,pType(A0,D0.l)  ; is this a loadable segment?
    bne     .loadElfpgmSegNotPTLD   ; no, it's not
    ; here we load a loadable segment
    ; we're only going to pay attention to physical address segments
    move.l  pPaddr(A0,D0.l),A1      ; get physical address to load segment to
    btst    #0,A1                   ; check for odd address
    beq     .loadELFpgmSegEven      ; address is already even, skip ahead
    addq.l  #1,A1                   ; increment target address so it's even
.loadELFpgmSegEven:
    move.l  pFileSz(A0,D0.l),D3     ; get size of segment in bytes
    cmp.l   #0,D3                   ; is this segment 0 bytes?
    beq     .loadElfpgmSegNotPTLD   ; if so, then skip it
    asl.l   #2,D3                   ; divide by 4 to get size in longwords
    move.l  pOffset(A0,D0.l),D4     ; get offset to segment in file image
    lea     0(A0,D4.l),A2           ; get pointer to segment in file image
.loadElfPgmSegCpyLp:                ; copy loop
    move.l  (A2)+,(A1)+             ; copy next longword
    dbra    D3,.loadElfPgmSegCpyLp  ; copy until counter = 0
    cmpa.l  A1,A4                   ; do we need to update our highest address?
    bgt     .loadElfpgmSegNotPTLD   ; skip ahead if no
    movea.l A1,A4                   ; update highest address pointer
.loadElfpgmSegNotPTLD:
    ; get ready to check next segment
    subq.w  #1,D1                   ; decrement segment counter
    add.l   D2,D0                   ; increment offset to next header entry
    bra     .loadELFpgmSeg          ; load next segment

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; All done, transfer control to the program now ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

runElfPgm:
    ; get entry point from ELF program header
    move.l  eEntry(A0),A1           ; get entry pointer in A1
    btst    #0,A1                   ; make sure it's even
    beq     .runElfPgmEven          ; it's already even
    addq.l  #1,A1                   ; make it even
.runElfPgm:
    move.l  #elfExit,-(SP)          ; push return address
    move.l  A1,-(SP)                ; push jump address

; one last thing to do before jumping to the program. We're going to set A0 to
; the base of free memory after the end of its loaded data, and we're going to 
; set D0 to the amount of free memory between A0 and SP.
; (This is used by ehBASIC to make it relocatable)
    move.l  A4,D1                   ; we kept track of highest address in A4
    move.l  SP,D0                   ; get current stack pointer
    sub.l   D1,D0                   ; get current free memory
    move.l  D1,A0                   ; get pointer to base of free memory

    rts                             ; start executing ELF binary

elfExit:
    ; if we make it here, then the ELF exited and we need to restart monitor
    ; we have no idea what is the current state of memory, the stack, I/O, etc.
    ; so a fresh restart is the best option here.
    lea     romBot,A0               ; get pointer to bottom of ROM
    jmp     4(A0)                   ; reload initial PC from ROM & jump there


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads a sector using system calls ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  D0.L  = LBA               ;;
;;         D2.W  = sector count      ;;
;;         A0.L  -> buffer address   ;;
;; Output: CF = 1 if error           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadSector: