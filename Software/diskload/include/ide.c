

#include "ide.h"
#include "hardware.h"
#include "types.h"
#include "endianswap.h"

// check the disk busy status bit
inline Boolean ideDiskIsBusy()
{
    if(read_IDE_com_Stat() & ideStatusBSY) return true;
    else return false;
}

// check the disk ready status bit
inline Boolean ideDiskIsReady()
{
    if(read_IDE_com_Stat() & ideStatusDRDY) return true;
    else return false;
}

// check the disk error status bit
inline Boolean ideDiskError()
{
    if(read_IDE_com_Stat() & ideStatusERR) return true;
    else return false;
}

// read all data from the specified sector and save to the provided buffer
// returns 0 for success
// returns <0 for error
signed char ideReadSector(uint16_t * readBuf, uint32_t sector)
{
    uint8_t lbaLL, lbaLM, lbaHM, lbaHH;
    uint16_t i, errCount;
    uint16_t * ptrBuf = readBuf;
    if(ideDiskIsReady() == false) return errIDE_notReady;


    // split up the sector into 8-bit register values
    lbaLL = (uint8_t)(sector & 0xFF);
    lbaLM = (uint8_t)((sector >> 8) & 0xFF);
    lbaHM = (uint8_t)((sector >> 16) & 0xFF);
    lbaHH = (uint8_t)((sector >> 24) & 0x0F);
    lbaHH = lbaHH | 0x40;   // make sure we set the enable LBA bit

    // set the LBA registers
    write_IDE_com_LBALL(lbaLL);
    write_IDE_com_LBALM(lbaLM);
    write_IDE_com_LBAHM(lbaHM);
    write_IDE_com_LBAHH(lbaHH);

    // set sector count to 1
    write_IDE_com_sect(0x01);

    // send read command
    write_IDE_com_Cmnd(ideCmd_ReadSects);

    // read 256 words from disk (one sector)
    for(i=0; i<256; i++)
    {
        errCount = 0;
        while(ideDiskIsBusy() == true)
        {
            errCount++;
            if(errCount > ideReadTimeoutTries)
            {
                // we're going to give up here
                ideReset();
                return errIDE_readTimeout;
            }
        }
        // check error bit
        if(ideDiskError() == true)
        {
            return errIDE_readError;
        }
        // read word into buffer
        #ifdef _IDE_BUS_SWAP_BUG_FIX
            // swap byte order before saving to correct a hardware error
            *ptrBuf = endianSwap16(read_IDE_com_data());
        #else
            *ptrBuf = read_IDE_com_data();
        #endif
        // increment buffer pointer
        ptrBuf++;
    }
    return 0;
}


// software reset disk
void ideReset()
{
    // reset the drive
    //*pIDE_ctl_DevC_wo = 0x0e;
    write_IDE_ctl_DevC(0x0e);
    // check drive busy status
    while(ideDiskIsBusy() == true);
    // then enable the drive
    //*pIDE_ctl_DevC_wo = 0x0a;
    write_IDE_ctl_DevC(0x0a);
}
