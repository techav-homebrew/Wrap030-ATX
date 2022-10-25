// IDE disk read functions
// I don't think we'll be needing any disk write for this program

#include "types.h"

#ifndef _ide_h
#define _ide_h

// swap data bus bytes on word reads to correct hardware bug
#define _IDE_BUS_SWAP_BUG_FIX 1

#define ideSectorSize 512

#define errIDE_notReady -1
#define errIDE_busy -2
#define errIDE_readTimeout -3
#define errIDE_readError -4

#define ideReadTimeoutTries 10000
#define ideReadyTimeoutTries 10000

#define ideStatusBSY 0x80
#define ideStatusDRDY 0x40
#define ideStatusDWF 0x20
#define ideStatusDSC 0x10
#define ideStatusDRQ 0x08
#define ideStatusCORR 0x04
#define ideStatusIDX 0x02
#define ideStatusERR 0x01

#define ideCmd_ReadSects 0x21

#define regIDE_com_data      (ideBase + ideComOffset + ideRegOffset0)
#define regIDE_com_error_ro  (ideBase + ideComOffset + ideRegOffset1)
#define regIDE_com_feats_wo  (ideBase + ideComOffset + ideRegOffset1)
#define regIDE_com_sect      (ideBase + ideComOffset + ideRegOffset2)
#define regIDE_com_LBALL     (ideBase + ideComOffset + ideRegOffset3)
#define regIDE_com_LBALM     (ideBase + ideComOffset + ideRegOffset4)
#define regIDE_com_LBAHM     (ideBase + ideComOffset + ideRegOffset5)
#define regIDE_com_LBAHH     (ideBase + ideComOffset + ideRegOffset6)
#define regIDE_com_Stat_ro   (ideBase + ideComOffset + ideRegOffset7)
#define regIDE_com_Cmnd_wo   (ideBase + ideComOffset + ideRegOffset7)
#define regIDE_ctl_Stat_ro   (ideBase + ideCtlOffset + ideRegOffset6)
#define regIDE_ctl_DevC_wo   (ideBase + ideCtlOffset + ideRegOffset6)
#define regIDE_ctl_DevA_ro   (ideBase + ideCtlOffset + ideRegOffset7)

/***************************/
#define write_IDE_com_data(val) ((*(volatile uint16_t *)regIDE_com_data) = (val))
#define read_IDE_com_data() (*(volatile uint16_t *)regIDE_com_data)

#define write_IDE_com_feats(val) ((*(volatile uint8_t *)regIDE_com_feats_wo) = (val))
#define read_IDE_com_error() (*(volatile uint8_t *)regIDE_com_error_ro)

#define write_IDE_com_sect(val) ((*(volatile uint8_t *)regIDE_com_sect) = (val))
#define read_IDE_com_sect() (*(volatile uint8_t *)regIDE_com_sect)

#define write_IDE_com_LBALL(val) ((*(volatile uint8_t *)regIDE_com_LBALL) = (val))
#define read_IDE_com_LBALL() (*(volatile uint8_t *)regIDE_com_LBALL)

#define write_IDE_com_LBALM(val) ((*(volatile uint8_t *)regIDE_com_LBALM) = (val))
#define read_IDE_com_LBALM() (*(volatile uint8_t *)regIDE_com_LBALM)

#define write_IDE_com_LBAHM(val) ((*(volatile uint8_t *)regIDE_com_LBAHM) = (val))
#define read_IDE_com_LBAHM() (*(volatile uint8_t *)regIDE_com_LBAHM)

#define write_IDE_com_LBAHH(val) ((*(volatile uint8_t *)regIDE_com_LBAHH) = (val))
#define read_IDE_com_LBAHH() (*(volatile uint8_t *)regIDE_com_LBAHH)

#define write_IDE_com_Cmnd(val) ((*(volatile uint8_t *)regIDE_com_Cmnd_wo) = (val))
#define read_IDE_com_Stat() (*(volatile uint8_t *)regIDE_com_Stat_ro)

#define write_IDE_ctl_DevC(val) ((*(volatile uint8_t *)regIDE_ctl_DevC_wo) = (val))
#define read_IDE_ctl_Stat() (*(volatile uint8_t *)regIDE_ctl_Stat_ro)

#define read_IDE_ctl_DevA() (*(volatile uint8_t *)regIDE_ctl_DevA_ro)
/***************************/

signed char ideReadSector(uint16_t *, uint32_t);

void ideReset();

Boolean ideDiskIsBusy();
Boolean ideDiskIsReady();
Boolean ideDiskError();



#endif