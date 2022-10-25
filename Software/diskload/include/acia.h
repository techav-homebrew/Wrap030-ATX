#include "types.h"

#ifndef _acia_h
#define _acia_h


#define regACIA1_com_wo (acia1Base+aciaComOffset)
#define regACIA1_stat_ro (acia1Base+aciaComOffset)
#define regACIA1_data (acia1Base+aciaDatOffset)

#define write_acia1_com(val) ((*(volatile uint8_t *)regACIA1_com_wo) = (val))
#define read_acia1_stat() (*(volatile uint8_t *)regACIA1_stat_ro)
#define write_acia1_data(val) ((*(volatile uint8_t *)regACIA1_data) = (val))
#define read_acia1_data() (*(volatile uint8_t *)regACIA1_data)

#define regACIA2_com_wo (acia2Base+aciaComOffset)
#define regACIA2_stat_ro (acia2Base+aciaComOffset)
#define regACIA2_data (acia2Base+aciaDatOffset)

#define write_acia2_com(val) ((*(volatile uint8_t *)regACIA2_com_wo) = (val))
#define read_acia2_stat() (*(volatile uint8_t *)regACIA2_stat_ro)
#define write_acia2_data(val) ((*(volatile uint8_t *)regACIA2_data) = (val))
#define read_acia2_data() (*(volatile uint8_t *)regACIA2_data)



char putc(char, char);      // print character (nonblocking)
char getc(char);            // get character (nonblocking)

void prints(char, char*);   // print string (blocking)
char* reads(char);          // get string (blocking)

char _aciaStatus(char);     // get status byte

Boolean _aciaTxRdy(char);      // check if ready to transmit
Boolean _aciaRxRdy(char);      // check if Rx byte available

void printNyb(char,uint8_t);
void printByt(char,uint8_t);
void printWrd(char,uint16_t);
void printLng(char,uint32_t);

#endif