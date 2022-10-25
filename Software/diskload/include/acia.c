
#include "types.h"
#include "acia.h"
#include "hardware.h"


// get status byte from specified port
inline char _aciaStatus(char port)
{
    if(port==1) return read_acia2_stat();
    else return read_acia1_stat();
}

// check if ready to transmit
Boolean _aciaTxRdy(char port)
{
    char status;
    status = _aciaStatus(port);
    if(status & 0x02)
    {
        return true;
    }
    else
    {
        return false;
    }
}

// check if Rx byte available
Boolean _aciaRxRdy(char port)
{
    char status;
    status = _aciaStatus(port);
    if(status & 0x01)
    {
        return true;
    }
    else
    {
        return false;
    }
}

// print character (nonblocking)
// returns -1 if ACIA not ready
// returns 0 if ACIA ready & byte transmitted
char putc(char port, char c)
{
    if(_aciaTxRdy(port) == true)
    {
        // send byte
        if(port==1) write_acia2_data(c);
        else write_acia1_data(c);
        return 0;
    }
    else
    {
        return -1;
    }
}

// get character (nonblocking)
// returns -1 if no byte received
// returns char if byte received
char getc(char port)
{
    char c;

    // read the ACIA command port to get current status;
    if(_aciaRxRdy(port) == true)
    {
        // get byte
        if(port==1) return read_acia2_data();
        else return read_acia1_data();
    }
    else
    {
        return -1;
    }
}

// print null-terminated string (blocking)
void prints(char port, char* str)
{
    char * strPtr = 0;
    char c, status;

    strPtr = str;

    // fetch the first byte of the string
    c = *strPtr;
    while(c != 0)
    {
        // keep trying to send the byte until we get back status 0
        do
        {
            status = putc(port, c);
        } while(status != 0);
    }
}

char* reads(char);         // get string (blocking)


// print a single nybble as hex (blocking)
void printNyb(char port,uint8_t Nyb)
{
    char c = Nyb & 0x0f;
    if(c < 10) { c = (c | '0'); }
    else { c = (c | 'A'); }

    // wait for ACIA to be ready
    while(_aciaTxRdy(port) == false);
    putc(port,c);
}
// print a single byte as hex (blocking)
void printByt(char port,uint8_t Byt)
{
    char c;
    c = (Byt >> 4) & 0x0f;
    printNyb(port,c);
    c = Byt & 0x0f;
    printNyb(port,c);
}
// print a word as hex (blocking)
void printWrd(char port,uint16_t Wrd)
{
    uint8_t c;
    c = (uint8_t)((Wrd >> 8) & 0xff);
    printByt(port,c);
    c = (uint8_t)(Wrd & 0xff);
    printByt(port,c);
}
// print a long word as hex (blocking)
void printLng(char port,uint32_t Lng)
{
    uint16_t c;
    c = (uint16_t)((Lng >> 16) & 0xffff);
    printWrd(port,c);
    c = (uint16_t)(Lng & 0xffff);
    printWrd(port,c);
}