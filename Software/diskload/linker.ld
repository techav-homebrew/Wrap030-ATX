MEMORY
{
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00200000
    rom (rx)  : ORIGIN = 0x00200000, LENGTH = 0x00080000
}

SECTIONS {
    . = 0x00000000;
    . = ALIGN(4);
    PROVIDE (_ramvecstart = .);

    . = 0x00000400;
    .bss (NOLOAD) :
    {
        * (.bss .bss.*)
    } > ram

    . = 0x00000500;
    PROVIDE (_heapstart = .);

    . = 0x00200000;
    PROVIDE (_stackstart = .);
    .text : 
    {
        . = ALIGN(4);
        KEEP(* (.vector));
        * (.text .text.*);
    } > rom
    .rodata : 
    { 
        * (.rodata); 
    } > rom
}