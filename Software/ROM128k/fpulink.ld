ramBot     = 0x00000000;
ramTop     = 0x007FFFFF;    /* 8MB */
stackTop   = ramTop + 1;
romSector0 = 0xF0000000;
romSector1 = 0xF0010000;

MEMORY
{
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x01000000
    rom (rx)  : ORIGIN = 0xf0000000, LENGTH = 0x00020000
}

/* acia1Com = 0x00380000;
acia1Dat = acia1Com + 4;
acia2Com = acia1Com + 8;
acia2Dat = acia2Com + 4; */
spioPort = 0xDC000000;
spioCOM0 = spioPort + 0x00;
spioCOM1 = spioPort + 0x40;
spioLPT0 = spioPort + 0x80;

comRegRX    = (0*8); /* Receive Buffer Register (read only) (Requires LCR DLAB clear) */
comRegTX    = (0*8); /* Transmit Holding Register (write only) (Requires LCR DLAB clear) */
comRegIER   = (1*8); /* Interrupt Enable Register */
comRegIIR   = (2*8); /* Interrupt Identification Register (read only) */
comRegFCR   = (2*8); /* FIFO Control Register (write only) */
comRegLCR   = (3*8); /* Line Control Register */
comRegMCR   = (4*8); /* Modem Control Register */
comRegLSR   = (5*8); /* Line Status Register */
comRegMSR   = (6*8); /* Modem Status Register */
comRegSPR   = (7*8); /* Scratch Pad Register */
comRegDivLo = (0*8); /* Divisor Latch Register LSB (Requires LCR DLAB set) */
comRegDivHi = (1*8); /* Divisor Latch Register MSB (Requires LCR DLAB set) */

/* these are used for debugging in tsmon */
com0lsr = spioCOM0 + comRegLSR;
com0tx  = spioCOM0 + comRegTX;
com0mcr = spioCOM0 + comRegMCR;

vidBase  = 0xD0000000;
vidBuf0  = vidBase + 0x0000;
vidBuf1  = vidBase + 0x8000;
vidReg   = vidBase + 0xFFFF;
/* overlayPort = 0x00300000; */
busCtrlPort = 0xE0000000;
dramCtrlPort = ramBot + 0x3FFF0000;
romTop   = 0xF001FFFF;

ENTRY(_start)
SECTIONS {
    .tsmon :
    {
        tsmon.o ( text )
        exprom.o( text )
    } > rom = 0xff
    .null (NOLOAD) :
    {
        /* minimize what has to be written to ROM */
    } > rom = 0xff
    .basic 0xf0010000 : /* put BASIC on the second ROM sector */
    {
        ROMBASIC = . ;
        .basicStart = . ;
        fpubasic.o( text )
        .basicEnd = . ;
    }
    .bss 0x400 (NOLOAD) :
    {
        ramStart = . ;
        tsmon.o( bss )
        exprom.o( bss )
        fpubasic.o( bss )
        . = ALIGN(0x1000);
        RAMBASIC = . ;
        . += .basicEnd - .basicStart ;
        . = ALIGN(4);
        HEAPBASIC = . ;
        ram_addr = . ;
    } > ram
}

SIZBASIC = .basicEnd - .basicStart ;
