
ramBot              =   0x00000000
ramTop              =   0x001FFFFF
stackTop            =   ramTop+1

romBot              =   0x00200000
romTop              =   0x0027FFFF
romSector7          =   romBot+0x70000
romSector6          =   romBot+0x60000
romSector5          =   romBot+0x50000
romSector4          =   romBot+0x40000
romSector3          =   romBot+0x30000
romSector2          =   romBot+0x20000
romSector1          =   romBot+0x10000
romSector0          =   romBot

aciaDatOffset       =   4
acia1Com            =   0x00380000
acia1Dat            =   acia1Com+aciaDatOffset
acia2Com            =   0x00380008
acia2Dat            =   acia2Com+aciaDatOffset

# pick one of the two below for default ACIA settings
# 8N1,÷16 (38400),no interrupts
aciaSet             =   0x15
# 8N1,÷64 (9600),no interrupts
# aciaSet             =   0x16

# reset ACIA
aciaReset           =   0x03

overlayPort         =   0x00300000


    .extern main


.text


.globl  _start


# this is our entry point. It will call main() after initializing the system
_start:

# first, check if the ROM overlay is enabled and disable it
CheckOverlay:
    move.l  #0x55AA55AA,%d0     | load test pattern
    move.l  #ramBot,%a0         | get base memory address
    move.l  %d0,(%a0)           | write to first memory address
    cmp.l   (%a0),%d0           | confirm patterns match
    beq.s   ClearMainMem        | if matching, then overlay is already disabled
ClearOverlay:
    move.b  #0,overlayPort      | disable the startup overlay
ClearMainMem:
    move.l  #stackTop,%a0       | start at top of memory space
    move.l  #stackTop>>2,%d0    | set up loop counter
    moveq   #0,%d1              | clear D1 register to clear memory with
.clrRamLoop:
    move.l  %d1,-(%a0)          | clear memory address
    dbra    %d0,.clrRamLoop     | loop until counter expires

# initialize the two ACIA 
InitACIA:
    lea     acia1Com,%a0        | get settings address for ACIA 1
    move.b  #aciaReset,(%a0)    | reset ACIA 1
    move.b  #aciaSet,(%a0)      | configure ACIA 1
    lea     acia2Com,%a0        | get settings address for ACIA 0
    move.b  #aciaReset,(%a0)    | reset ACIA 2
    move.b  #aciaSet,(%a0)      | configure ACIA 2





# not sure if I'm doing this right, but try to call main()
    jsr     main
    jmp     _start              | if we make it back here, then reboot



