
; MEMORY MAP
;  512kB    RAM (ROM Overlay)      $0000,0000 - $0007,FFFF
;  512kB    RAM                    $0008,0000 - $000F,FFFF
;  512kB    RAM                    $0010,0000 - $0017,FFFF
;  512kB    RAM + Video Buffer     $0018,0000 - $001F,FFFF
;  512kB    ROM                    $0020,0000 - $0027,FFFF
;  512kB    [Empty,Bus Error]      $0028,0000 - $002F,FFFF
;  512kB    Overlay Switch         $0030,0000 - $0037,FFFF
;  512kB    ACIA                   $0038,0000 - $003F,FFFF
; 1.99GB    [Repeat Above]         $0040,0000 - $7FFF,FFFF
; 2.00GB    [Expansion]            $8000,0000 - $FFFF,FFFF

; ROM overlay is enabled on reset and allows ROM to be read from the first page
; RAM can still be written to on Page 0 when overlay is enabled.
; Writing to any address on page 6 will toggle the overlay.
; Overlay should already be disabled before TSMON is started.

; ROM MAP
;   64kB    TSMON                  $0020,0000 - $0020,FFFF
;   64kB    TSMON Expansion        $0021,0000 - $0021,FFFF
;   64kB    [Future]               $0022,0000 - $0022,FFFF
;   64kB    [Future]               $0023,0000 - $0023,FFFF
;   64kB    [Future]               $0024,0000 - $0024,FFFF
;   64kB    [Future]               $0025,0000 - $0025,FFFF
;   64kB    EhBASIC exp Calls      $0026,0000 - $0026,FFFF
;   64kB    Enhanced BASIC         $0027,0000 - $0027,FFFF

romBot              equ $00200000
romTop              equ $0027FFFF
romSector7          equ romBot+$70000       ; EhBASIC
romSector6          equ romBot+$60000       ; EhBASIC exp calls
romSector5          equ romBot+$50000       ; Font Data
romSector4          equ romBot+$40000
romSector3          equ romBot+$30000
romSector2          equ romBot+$20000
romSector1          equ romBot+$10000       ; TSMON exp ROM
romSector0          equ romBot              ; TSMON

expROM              equ romSector1

ramTop              equ $001FFFFF
vidBuf              equ $001FA700
vidBufEnd           equ $001FFC7F
;stackTop            equ ramTop+1
stackTop            equ vidBuf
ramBot              equ $00000000

acia1Com            equ $00380000
acia1Dat            equ acia1Com+4
acia2Com            equ $00380008
acia2Dat            equ acia2Com+4

acia2offset         equ 8
aciaDatOffset       equ 4

;aciaSet             equ $16            ; 8N1,÷64 (9600),no interrupts
aciaSet             equ $15            ; 8N1,÷16 (38400),no interrupts

overlayPort         equ $00300000

ideBase:            equ $80200000
ideCommand:         equ ideBase+$0000
ideControl:         equ ideBase+$2000
ideDataRW:          equ ideCommand+$0
ideErrorRO:         equ ideCommand+$2
ideFeatureWO:       equ ideCommand+$2
ideSectorCountRW:   equ ideCommand+$4
ideLBALLRW:         equ ideCommand+$6
ideLBALHRW:         equ ideCommand+$8
ideLBAHLRW:         equ ideCommand+$a
ideLBAHHRW:         equ ideCommand+$C
ideStatusRO:        equ ideCommand+$E
ideCommandWO:       equ ideCommand+$E
ideAltStatusRO:     equ ideControl+$C
ideDevControlWO:    equ ideControl+$C
ideDevAddressRO:    equ ideControl+$F

ideCmdReadSect:     equ $21             ; read sector command
ideCmdNOP:          equ $00             ; disk no operation command

; Symbol equates
BS:                 EQU $08            ; Backspace
CR:                 EQU $0D            ; Carriage Return
LF:                 EQU $0A            ; Line Feed
SPACE:              EQU $20            ; Space
WAIT:               EQU 'W'            ; Wait Character (to suspend output)
ESC:                EQU $1B            ; ASCII Escape (used by TM)
CTRL_A:             EQU $01            ; Control_A forces return to monitor

; Device addresses
STACK:              EQU stackTop       ; stack pointer
ACIA_1:             EQU acia1Com       ; console ACIA control
ACIA_2:             EQU acia2Com       ; aux ACIA control (not used)
X_BASE:             EQU $08            ; Start of exception vector table
TRAP_14:            EQU $4E4E          ; Code for TRAP #14
MAXCHR:             EQU 64             ; Length of line input buffer

DATA:               EQU ramBot+$C00  ; Data origin
LNBUFF:             DS.B MAXCHR        ; Input line buffer
BUFFEND:            EQU LNBUFF+MAXCHR-1 ; End of line buffer
BUFFPT:             DS.L 1             ; Pointer to line buffer
PARAMTR:            DS.L 1             ; Last parameter from line buffer
ECHO:               DS.B 1             ; When clear this enable input echo
U_CASE:             DS.B 1             ; Flag for uppercase conversion
UTAB:               DS.L 1             ; Pointer to user command table
CN_IVEC:            DS.L 1             ; Pointer to console input DCB
CN_OVEC:            DS.L 1             ; Pointer to console output DCB
TSK_T:              DS.W 37            ; Frame for D0-D7,A0-A6,USP,SSP,SW,PC
BP_TAB:             DS.W 24            ; Breakpoint table
FIRST:              DS.B 512           ; DCB area
BUFFER:             DS.B 256           ; 256 bytes for I/O Buffer
dskBUF:             DS.W 256           ; 512 byte disk sector buffer

startHeap:

trapGetChar:        EQU 0
trapPutChar:        EQU 1
trapNewLine:        EQU 2
trapGetParam:       EQU 3
trapPutString:      EQU 4
trapGetHexChar:     EQU 5
trapGetHexByte:     EQU 6
trapGetHexWord:     EQU 7
trapGetHexLong:     EQU 8
trapPutHexByte:     EQU 9
trapPutHexWord:     EQU 10
trapPutHexLong:     EQU 11
trapPutSpace:       EQU 12
trapGetLine:        EQU 13
trapTidyLine:       EQU 14
trapExecute:        EQU 15
trapRestore:        EQU 16

;******************************************************************************
; Generic macro for system calls

    MACRO callSYS
    move.l  D0,-(SP)            ; save the working register
    move.b  \1,D0               ; load syscall number
    trap    #0                  ; call syscall handler
    move.l  (SP)+,D0            ; restore the working register
    ENDM

;callPSTRING:    MACRO
;    MOVE.l  D0,-(SP)            ; save register
;    MOVE.b  #trapPutString,D0   ; use TSMON trap system call
;    TRAP    #0
;    MOVE.l  (SP)+,D0            ; restore register
;    ENDM