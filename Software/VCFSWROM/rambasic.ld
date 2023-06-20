/* linker script for assembling BASIC to run side-loaded instead of burned 
   to ROM and loaded into RAM from the monitor. */

ramBot     = 0x00000000;
romSector0 = 0x00200000;
romSector1 = 0x00210000;

MEMORY
{
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00200000
    rom (rx)  : ORIGIN = 0x00200000, LENGTH = 0x00020000
}

acia1Com = 0x00380000;
acia1Dat = acia1Com + 4;
acia2Com = acia1Com + 8;
acia2Dat = acia2Com + 4;
vidBase  = 0x80800000;
vidBuf0  = vidBase + 0x0000;
vidBuf1  = vidBase + 0x8000;
vidReg   = vidBase + 0xFFFF;
overlayPort = 0x00300000;
romTop   = 0x0021FFFF;

ENTRY(startBasic)
SECTIONS {
    .text 0x2000 :
    {
        ROMBASIC = . ;
        .basicStart = . ;
        fpubasic.o( text )
        .basicEnd = . ;
    }
    .bss 0x400 (NOLOAD) :
    {
        ramStart = . ;
        . = 0x000009d0 ;
        fpubasic.o( bss )
        . = ALIGN(0x2000);
        RAMBASIC = . ;
        . += .basicEnd - .basicStart ;
        . = ALIGN(4);
        HEAPBASIC = . ;
        ram_addr = . ;
    } > ram
}