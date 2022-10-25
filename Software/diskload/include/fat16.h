// read files from FAT16 disk. 
// Read only, does not support long file names or subdirectories.

#include "types.h"
#include "ide.h"
#include "malloc.h"

#ifndef _fat16_h
#define _fat16_h

// These are some helpful structures for dealing with FAT16 file systems

struct FatHead
{
    uint8_t  bs_JmpBoot[3];
    uint8_t  bs_OEM[8];
    uint16_t bpb_BytesPerSec;
    uint8_t  bpb_SecPerCluster;
    uint16_t bpb_RsvdSecCount;
    uint8_t  bpb_NumFATs;
    uint16_t bpb_RootEntCount;
    uint16_t bpb_TotalSec16;
    uint8_t  bpb_Media;
    uint16_t bpb_FATsize;
    uint16_t bpb_SecPerTrack;
    uint16_t bpb_NumHeads;
    uint32_t bpb_HiddenSec;
    uint32_t bpb_TotalSec;
    uint8_t  bs_DriveNum;
    uint8_t  bs_Reserved;
    uint8_t  bs_BootSig;
    uint8_t  bs_VolID[4];
    uint8_t  bs_VolLabel[11];
    uint8_t  bs_FileSysType[8];
//    uint8_t  bs_BootCode[448];
//    uint8_t  bs_BootSign[2];
};

struct FatRoot
{
    uint8_t  root_FileName[8];
    uint8_t  root_FileExt[3];
    uint8_t  root_FileAttr;
//    uint8_t  root_Reserved[10];
    uint16_t root_FileTime;
    uint16_t root_FileDate;
    uint16_t root_FirstCluster;
    uint32_t root_FileSize;
};

#define fattr_RO    0x01;
#define fattr_Hid   0x02;
#define fattr_Sys   0x04;
#define fattr_Lbl   0x08;
#define fattr_Sub   0x10;
#define fattr_Arch  0x20;

#define errFat_OutOfMemory -16
#define errFat_FileNotFound -17


// initialize & get ready to start reading from disk
signed char fatInit();

// function to parse FAT16 header data from a disk buffer in RAM
signed char fatHeadRead();


// functions for loading Root Directory entries
signed int FatRootOpen(void**,struct FatRoot*);
signed int FatRootNext(void**,struct FatRoot*, signed int);
void FatRootClose(int);
void _parseRoot(uint8_t*,struct FatRoot*);


// read in the File Allocation Table
void * FatCacheFAT(void*);

// find file in root directory & return its directory listing
signed char FatFindFile(struct FatRoot *, char*);

void FatFileReadFirstCluster(void*, struct FatRoot*);
void FatFileReadNextCluster(void*, struct FatRoot*);


#endif