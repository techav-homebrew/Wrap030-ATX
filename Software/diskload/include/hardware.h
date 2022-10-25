// define physical hardware addresses

#ifndef _hardware_030_h
#define _hardware_030_h 0

// RAM & ROM base addresses
#define ramBase 0x00000000
#define ramSize 0x00200000
#define bssSize 1024
#define heapStart (ramBase + (256*4) + bssSize)
#define stackStart (ramBase + ramSize)


// ACIA base addresses
#define acia1Base 0x00380000
#define acia2Base 0x00380008
#define aciaComOffset   0
#define aciaDatOffset   4

// Overlay switch device base address

// IDE base addresses
#define ideBase 0x80000000
#define ideComOffset    0x0000
#define ideCtlOffset    0x2000
#define ideRegOffset0   0x0000
#define ideRegOffset1   0x0002
#define ideRegOffset2   0x0004
#define ideRegOffset3   0x0006
#define ideRegOffset4   0x0008
#define ideRegOffset5   0x000A
#define ideRegOffset6   0x000C
#define ideRegOffset7   0x000E

#endif