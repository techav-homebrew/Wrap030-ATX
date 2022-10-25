

#include "fat16.h"
#include "str.h"
#include "endianswap.h"

// hold onto FAT header data some place convenient for future reference
struct FatHead _fatHead __attribute__ ((section (".bss")));


// get ready to start reading from disk
// returns 0 for success
// returns <0 for error
signed char fatInit()
{
    signed char fatErr;
    // first, allocate some memory for our header structure

    // read the file system header using the buffer just allocated
    fatErr = fatHeadRead();
    if(fatErr < 0) return fatErr;
}

// function to read the first disk sector & parse FAT16 header
// returns 0 for success
// returns <0 for error
signed char fatHeadRead()
{
    signed char ideErr;
    uint8_t * ptrBuf = 0;
    
    // grab a buffer for storing the header sector
    ptrBuf = (uint8_t*)malloc(ideSectorSize);
    if(ptrBuf == 0)
    {
        // we got a memory error allocating a buffer
        return errFat_OutOfMemory;
    }

    // read header sector (0)
    ideErr = ideReadSector((uint16_t*)ptrBuf,0);
    if(ideErr < 0)
    { 
        // error reading from disk
        // free our buffer and return the error
        free(ideSectorSize);
        return ideErr;
    }

    // now load the read data into our structure
    // ... There's got to be a better way to do this ..
    _fatHead.bs_JmpBoot[0] = *(ptrBuf + 0);
    _fatHead.bs_JmpBoot[1] = *(ptrBuf + 1);
    _fatHead.bs_JmpBoot[2] = *(ptrBuf + 2);
    ptrBuf += 3;

    _fatHead.bs_OEM[0] = *(ptrBuf + 0);
    _fatHead.bs_OEM[1] = *(ptrBuf + 1);
    _fatHead.bs_OEM[2] = *(ptrBuf + 2);
    _fatHead.bs_OEM[3] = *(ptrBuf + 3);
    _fatHead.bs_OEM[4] = *(ptrBuf + 4);
    _fatHead.bs_OEM[5] = *(ptrBuf + 5);
    _fatHead.bs_OEM[6] = *(ptrBuf + 6);
    _fatHead.bs_OEM[7] = *(ptrBuf + 7);
    ptrBuf += 8;

    _fatHead.bpb_BytesPerSec = endianSwap16(*((uint16_t*)ptrBuf));
    ptrBuf += 2;

    _fatHead.bpb_SecPerCluster = *ptrBuf;
    ptrBuf += 1;

    _fatHead.bpb_RsvdSecCount = endianSwap16(*((uint16_t*)ptrBuf));
    ptrBuf += 2;

    _fatHead.bpb_NumFATs = *ptrBuf;
    ptrBuf += 1;

    _fatHead.bpb_RootEntCount = endianSwap16(*((uint16_t*)ptrBuf));
    ptrBuf += 2;

    _fatHead.bpb_TotalSec16 = endianSwap16(*((uint16_t*)ptrBuf));
    ptrBuf += 2;

    _fatHead.bpb_Media = *ptrBuf;
    ptrBuf += 1;

    _fatHead.bpb_FATsize = endianSwap16(*((uint16_t*)ptrBuf));
    ptrBuf += 2;

    _fatHead.bpb_SecPerTrack = endianSwap16(*((uint16_t*)ptrBuf));
    ptrBuf += 2;

    _fatHead.bpb_NumHeads = endianSwap16(*((uint16_t*)ptrBuf));
    ptrBuf += 2;

    _fatHead.bpb_HiddenSec = endianSwap32(*((uint32_t*)ptrBuf));
    ptrBuf += 4;

    _fatHead.bpb_TotalSec = endianSwap32(*((uint32_t*)ptrBuf));
    ptrBuf += 4;

    _fatHead.bs_DriveNum = *ptrBuf;
    ptrBuf += 1;

    _fatHead.bs_Reserved = *ptrBuf;
    ptrBuf += 1;

    _fatHead.bs_BootSig = *ptrBuf;
    ptrBuf += 1;
    
    _fatHead.bs_VolID[0] = *(ptrBuf + 0);
    _fatHead.bs_VolID[1] = *(ptrBuf + 1);
    _fatHead.bs_VolID[2] = *(ptrBuf + 2);
    _fatHead.bs_VolID[3] = *(ptrBuf + 2);
    ptrBuf += 4;
    
    _fatHead.bs_VolLabel[0] = *(ptrBuf + 0);
    _fatHead.bs_VolLabel[1] = *(ptrBuf + 1);
    _fatHead.bs_VolLabel[2] = *(ptrBuf + 2);
    _fatHead.bs_VolLabel[3] = *(ptrBuf + 3);
    _fatHead.bs_VolLabel[4] = *(ptrBuf + 4);
    _fatHead.bs_VolLabel[5] = *(ptrBuf + 5);
    _fatHead.bs_VolLabel[6] = *(ptrBuf + 6);
    _fatHead.bs_VolLabel[7] = *(ptrBuf + 7);
    _fatHead.bs_VolLabel[8] = *(ptrBuf + 8);
    _fatHead.bs_VolLabel[9] = *(ptrBuf + 9);
    _fatHead.bs_VolLabel[10] = *(ptrBuf + 10);
    ptrBuf += 11;
    
    _fatHead.bs_FileSysType[0] = *(ptrBuf + 0);
    _fatHead.bs_FileSysType[1] = *(ptrBuf + 1);
    _fatHead.bs_FileSysType[2] = *(ptrBuf + 2);
    _fatHead.bs_FileSysType[3] = *(ptrBuf + 3);
    _fatHead.bs_FileSysType[4] = *(ptrBuf + 4);
    _fatHead.bs_FileSysType[5] = *(ptrBuf + 5);
    _fatHead.bs_FileSysType[6] = *(ptrBuf + 6);
    _fatHead.bs_FileSysType[7] = *(ptrBuf + 7);
    ptrBuf += 8;

    // free our sector buffer before returning
    free(ideSectorSize);

    return 0;
}


// functions for loading Root Directory entries

// given a pointer to a root directory entry in RAM,
// parse into a FatRoot structure
void _parseRoot(uint8_t* ptrBuf,struct FatRoot* ptrRoot)
{
    uint8_t *workingBuf = ptrBuf;
    //
    ptrRoot->root_FileName[0] = *(workingBuf + 0);
    ptrRoot->root_FileName[1] = *(workingBuf + 1);
    ptrRoot->root_FileName[2] = *(workingBuf + 2);
    ptrRoot->root_FileName[3] = *(workingBuf + 3);
    ptrRoot->root_FileName[4] = *(workingBuf + 4);
    ptrRoot->root_FileName[5] = *(workingBuf + 5);
    ptrRoot->root_FileName[6] = *(workingBuf + 6);
    ptrRoot->root_FileName[7] = *(workingBuf + 7);
    workingBuf += 8;

    ptrRoot->root_FileExt[0] = *(workingBuf + 0);
    ptrRoot->root_FileExt[1] = *(workingBuf + 1);
    ptrRoot->root_FileExt[2] = *(workingBuf + 2);
    workingBuf += 3;

    ptrRoot->root_FileAttr = *(workingBuf + 0);
    workingBuf += 1;

    // skip the reserved bytes
    workingBuf += 10;

    ptrRoot->root_FileTime = endianSwap16(*((uint16_t*)workingBuf));
    workingBuf += 2;

    ptrRoot->root_FileDate = endianSwap16(*((uint16_t*)workingBuf));
    workingBuf += 2;

    ptrRoot->root_FirstCluster = endianSwap16(*((uint16_t*)workingBuf));
    workingBuf += 2;

    ptrRoot->root_FileSize = endianSwap32(*((uint32_t*)workingBuf));
    workingBuf += 4;
}

// load root directory from disk into provided pointer.
// find first directory entry and load to provided pointer
// returns <0 for error
// returns >0 (buffer size allocated) on success
signed int FatRootOpen(void **ptrBuf, struct FatRoot *firstRoot)
{
    uint32_t rootDirSize;           // total size of root directory in Bytes
    uint32_t rootDirStartSector;    // disk sector where root directory begins
    uint32_t rootDirSizeSects;      // total number of sectors to load root dir
    uint8_t * workingBuf;           // this will just make assignments easier later
    signed char retErr;
    uint16_t i;

    rootDirSize = _fatHead.bpb_RootEntCount * 32;
    rootDirStartSector = (_fatHead.bpb_FATsize * _fatHead.bpb_NumFATs) + 1;
    rootDirSizeSects = rootDirSize >> 9;
    if((rootDirSizeSects << 9) < rootDirSize) rootDirSizeSects += 1;

    // allocate a buffer for storing the root directory
    *ptrBuf = malloc(rootDirSizeSects * ideSectorSize);
    if(*ptrBuf == 0)
    {
        // out of memory error
        return errFat_OutOfMemory;
    }
    workingBuf = *ptrBuf;

    // read all root directory sectors into buffer
    for(i=0; i<_fatHead.bpb_RootEntCount; i++)
    {
        retErr = ideReadSector((uint16_t*)(workingBuf+(i*ideSectorSize)), rootDirStartSector);
        if(retErr <0)
        {
            free(rootDirSizeSects * ideSectorSize);
            return retErr;
        }
    }

    // parse the first root directory entry
    _parseRoot(workingBuf,firstRoot);

    // return buffer size
    return (rootDirSizeSects * ideSectorSize);
}

// find next root directory entry and load to provided pointer
// returns <0 for error
// returns  0 for end of directory
// returns >0 (file entry #) on success
signed int FatRootNext(void** ptrBuf,struct FatRoot* nextRoot, signed int entry)
{
    uint8_t *ptr = *ptrBuf;
    if(entry + 1 > _fatHead.bpb_RootEntCount)
    {
        // no more directory entries
        return 0;
    }
    ptr += (entry+1)*32;
    _parseRoot(ptr,nextRoot);
    return entry + 1;
}

// close out root directory & free buffer
void FatRootClose(int size)
{
    free(size);
}

// find file in root directory & return its directory listing
// filename parameter should be in "filename.ext",0 format
// returns 0 if successful
// returns <0 on error
signed char FatFindFile(struct FatRoot * fileRoot, char* SearchFileName)
{
    signed int retVal, rootDirSize;
    void **ptrBuf = 0;
    char fileNameExt[13];
    Boolean fileFound = false;
    // open root directory and read first entry
    rootDirSize = FatRootOpen(ptrBuf,fileRoot);
    if(rootDirSize < 0) { return rootDirSize; }

    do
    {
        // concatenate the name & extension for the current root directory entry
        strconcat(fileNameExt,fileRoot->root_FileName);
        strconcat(fileNameExt,".");
        strconcat(fileNameExt,fileRoot->root_FileExt);

        // check if the current file matches what we're looking for
        if(strcmp(fileNameExt,SearchFileName)==true)
        {
            // we've found a match!
            fileFound = true;
            break;
        }
        else
        {
            // this file wasn't a match, load next root directory entry
            retVal = FatRootNext(ptrBuf,fileRoot,retVal);
            if(retVal < 0) 
            { 
                // we've encountered an error
                fileFound = false;
            }
            else if(retVal == 0) 
            {
                // this was the last entry in the root directory
                // and we haven't found the file we're looking for
                fileFound = false;
                break;
            }
        }
    } while(retVal <= 0);
    
    // clean up root directory search data
    FatRootClose(rootDirSize);

    if(fileFound == true) return 0;
    else if(retVal < 0) return retVal;
    else return errFat_FileNotFound;
}
