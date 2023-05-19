romAddr         equ     $f0000000
romBot          equ     $00000000
ramBot          equ     $00000000
;ramTop      equ $01ffffff
; set up program to only test the first 8MB in the first SIMM slot
ramTop          equ     $007fffff

initStack       equ     $00000800    ;initial stack pointer at top of first 2k DRAM page

romSect0        equ     romBot+$00000
romSect1        equ     romBot+$10000
romSect2        equ     romBot+$20000
romSect3        equ     romBot+$30000
romSect4        equ     romBot+$40000
romSect5        equ     romBot+$50000
romSect6        equ     romBot+$60000
romSect7        equ     romBot+$70000
romTop          equ     romSect7+$ffff

busCtrlPort     equ     $e0000000
dramCtrlPort    equ     ramBot+$3fff0000

; SPIO addressing
spioPort        equ     $dc000000
; CPU A[5:3] wired to SPIO A[2:0]
; CPU A[7:6] select SPIO devices:
;   00 - COM0
;   01 - COM1
;   02 - LPT0
;   03 - Not used
spioCOM0        equ     spioPort + $00
spioCOM1        equ     spioPort + $40
spioLPT0        equ     spioPort + $80

; COM Port Addresses
comRegRX        equ (0*8)  ; Receive Buffer Register (read only) (Requires LCR DLAB clear)
comRegTX        equ (0*8)  ; Transmit Holding Register (write only) (Requires LCR DLAB clear)
comRegIER       equ (1*8)  ; Interrupt Enable Register
comRegIIR       equ (2*8)  ; Interrupt Identification Register (read only)
comRegFCR       equ (2*8)  ; FIFO Control Register (write only)
comRegLCR       equ (3*8)  ; Line Control Register
comRegMCR       equ (4*8)  ; Modem Control Register
comRegLSR       equ (5*8)  ; Line Status Register
comRegMSR       equ (6*8)  ; Modem Status Register
comRegSPR       equ (7*8)  ; Scratch Pad Register
comRegDivLo     equ (0*8)  ; Divisor Latch Register LSB (Requires LCR DLAB set)
comRegDivHi     equ (1*8)  ; Divisor Latch Register MSB (Requires LCR DLAB set)


CR              equ     $0d
LF              equ     $0a