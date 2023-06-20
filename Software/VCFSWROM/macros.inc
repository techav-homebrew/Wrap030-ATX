
| macro for printing debugging markers
    .macro debugPrint char
L\@lp:
    btst    #5,com0lsr       | check if TX FIFO empty
    beq.s   L\@lp                       | loop until ready
    move.b  #\char,com0tx    | send byte
    .endm

|L\@lp:
|    btst    #1,acia1Com                 | check txrdy bit
|    beq.s   L\@lp                       | loop until ready
|    move.b  #\char,acia1Dat             | send byte
|    .endm

| macro for printing ascii from a register
    .macro debugAsciiReg regInA
L\@lpA:
    btst    #5,com0lsr       | check if TX FIFO empty
    beq.s   L\@lpA                      | loop until ready
    move.b  \regInA,com0tx   | send char
    .endm

|L\@lpA:
|    btst    #1,acia1Com                 | check txrdy bit
|    beq.s   L\@lpA                      | loop until ready
|    move.b  \regInA,acia1Dat            | send char
|    .endm

| macro for printing byte registers as ascii hex
| preserves register byte value, but cobbles register word value
| touches no other registers
    .macro debugReg regIn
|    debugPrint '$'
    ror.b  #4,\regIn                    | low nybble into position
    lsl.w  #4,\regIn
    ror.b  #4,\regIn
    cmp.b  #0xA,\regIn                  | check >A
    bge.s  L\@GEALo
    add.b  #0x30,\regIn                 | ascii number 0-9
    debugAsciiReg \regIn                | print it
    and.b  #0xF,\regIn                  | strip ascii from it
    bra.s  L\@Hi                        | jump ahead to hi nybble
L\@GEALo:
    add.b  #0x41,\regIn                 | ascii number A-F
    debugAsciiReg \regIn                | print it
    sub.b  #0x41,\regIn                 | strip ascii from it
L\@Hi:
    ror.w  #8,\regIn                    | high nybble into position
    and.b  #0xF,\regIn
    cmp.b  #0xA,\regIn                  | check >A
    bge.s  L\@GEAHi
    add.b  #0x30,\regIn                 | ascii number 0-9
    debugAsciiReg \regIn                | print it
    and.b  #0xf,\regIn                  | strip ascii from it
    bra.s  L\@EndMac                    | jump ahead
L\@GEAHi:
    add.b  #0x41,\regIn                 | ascii number A-F
    debugAsciiReg \regIn                | print it
    sub.b  #0x41,\regIn                 | strip ascii from it
L\@EndMac:
    lsl.b  #4,\regIn                    | reassemble byte
    lsr.w  #4,\regIn
    .endm

| macro for configuring 16c550 compatible uart
| expects Address register parameter, loaded with pointer to COM port base
    .macro  initCOM comAddr
    move.b  #0x07,comRegFCR(\comAddr)   | enable COM0 FIFO
    | move.b  #0x00,comRegFCR(\comAddr)   | disable COM0 FIFO, use poll mode
    nop
    move.b  #0x03,comRegLCR(\comAddr)   | set COM0 for 8N1
    nop 
    move.b  #0x00,comRegIER(\comAddr)   | disable COM0 interrupts
    nop 
    move.b  #0x83,comRegLCR(\comAddr)   | enable divisor registers
    nop 
    move.b  #0x03,comRegDivLo(\comAddr) | set divisor low byte for 38400
    nop
    move.b  #0x00,comRegDivHi(\comAddr) | set divisor high byte for 38400
    nop 
    move.b  #0x03,comRegLCR(\comAddr)   | disable divisor register
    nop
    .endm

