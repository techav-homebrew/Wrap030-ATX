MEMORY
{
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00200000
    rom (rx)  : ORIGIN = 0x00200000, LENGTH = 0x00080000
}

ENTRY(_start)
SECTIONS {
    .text 0x10000:
    {
        * (.text CODE);
    }
    .bss (NOLOAD) : { *(BSS) }
}
