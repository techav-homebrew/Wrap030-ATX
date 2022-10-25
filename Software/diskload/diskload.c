/* diskload.c
 * techav 2022/10/21
 *
 * this is a ROM-resident program for loading an ELF from a FAT16 IDE disk
 * 
 * we're outside the realm of libc here though, so lots of DIY
*/

#include "include/hardware.h"
#include "include/elf.h"
#include "include/fat16.h"
#include "include/acia.h"
#include "include/ide.h"
#include "include/malloc.h"
#include "include/str.h"
#include "include/types.h"

#define BOOTFILENAME "KERNEL  .ELF"

void main()
{
    // declare variables here
    signed char errVal = 0;
    uint16_t diskTimeout = 0;

    // pointer to the root entry for the kernel file we'll be loading
    struct FatRoot * kernelRoot = 0;
    int * memInitPtr = (int*)ramBase;

    // first thing we need to do is initialize the new vector table at the
    // bottom of RAM. We start with the initial stack pointer value, then 
    // copy the address main() to all 255 exception vector locations
    memInitPtr = (int*)stackStart;
    for (int i=0; i<255; i++)
    {
        memInitPtr++;
        memInitPtr = (int*)&main;
    }
    
    // now initialize our memory handler at the start of heap,
    // after the vector table we just initialized.
    minit((void*)(memInitPtr+1024));

    // this would be a good time to print a helpful message over serial
    prints(0,"\r\nLoading ...");

    // get ready to start reading from disk
    errVal = fatInit();
    if(errVal < 0)
    {
        // error reading file system header
        prints(0,"\r\nError 0x");
        printByt(0,(uint8_t)errVal);
        prints(0," reading file system header");
        for(;;);
    }

    errVal = FatFindFile(kernelRoot, BOOTFILENAME);
    if(errVal != 0)
    {
        // specified boot file was not found
        prints(0,"\r\nFile not found: ");
        prints(0,BOOTFILENAME);
        for(;;);
    }
}