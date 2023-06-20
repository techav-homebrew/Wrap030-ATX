|; Wrap030-ATX demo program for VCFSW 2023
|; prompts user to enter their name, then uses an Apple ImageWriter II on COM1
|; to print a sheet with a header image and the name that was entered
|; names will be printed using ASCII-art style 8x8 capital letters

    .section text,"ax"
    .extern spioPort
    .extern spioCOM0
    .extern spioCOM1
    .extern spioLPT0
    .extern comRegRX
    .extern comRegTX
    .extern comRegIER
    .extern comRegIIR
    .extern comRegFCR
    .extern comRegLCR
    .extern comRegMCR
    .extern comRegLSR
    .extern comRegMSR
    .extern comRegSPR
    .global namewriter
    .include    "Namewriter/system.s"   |; this has some helpful macros
    .equ    ULENMAX, 15                 |; max length of user string


|;******** Program initialization
namewriter:
    callSYS trapNewLine                 |; start by printing a newline
    lea     %pc@(strHeader),%a4         |; get pointer to header string
    callSYS trapPutString               |; and print it

printerInit:
    lea     spioCOM1,%a1                |; get pointer to aux COM port
    move.b  #0x00,%a1@(comRegFCR)       |; disable FIFO
    nop
    move.b  #0x83,%a1@(comRegLCR)       |; enable divisor registers
    nop 
    move.b  #0x0C,%a1@(comRegDivLo)     |; set divisor low byte for 9600
    nop
    move.b  #0x00,%a1@(comRegDivHi)     |; set divisor high byte for 9600
    nop 
    move.b  #0x03,%a1@(comRegLCR)       |; disable divisor register
    nop
    

|;******** Prompt user for name input
userprompt:
    callSYS trapNewLine
    lea     %pc@(strNamePrompt),%a4     |; get user name prompt
    callSYS trapPutString               |; and print it
    callSYS trapGetLine                 |; get line from user
    |; string from GETLINE will be terminated with CR, and the start of the
    |; string will be at %a6@(LNBUFF)
    lea     %a6@(LNBUFF),%a1            |; get pointer to start of string
    eor.b   %d1,%d1                     |; clear loop counter
userclean:
    cmpi.b  #ULENMAX,%d1                |; are we at the end of the buffer?
    beq.s   userconfirm                 |; if yes then start printing
    move.b  %a1@,%d0                    |; else get character from buffer

    cmpi.b  #0x0d,%d0                   |; is this the end of the string?
    beq.s   usercleanCR                 |; jump ahead, else continue cleanup
    cmpi.b  #0x20,%d0                   |; compare with ascii space
    blt.s   usercleansymbol             |; if non-print then convert to symbol
    cmpi.b  #0x5f,%d0                   |; compare with ascii underscore
    bgt.s   usercleanalpha              |; if lowercase, then convert to cap

usercleanend:
    move.b  %d0,%a1@+                   |; save back to buffer and inc pointer
    addi.b  #1,%d1                      |; increment loop counter
    cmpi.b  #0,%d0                      |; was this the end of the string?
    bne.s   userclean                   |; if not, then keep looping
    bra.s   userconfirm                 |; else jump to user confirmation

usercleansymbol:
    ori.b   #0b00100000,%d0             |; set bit to convert nonprint to symbol
    bra.s   usercleanend                |; continue processing
usercleanalpha:
    andi.b  #0b01011111,%d0             |; clear bit to convert to uppercase
    bra.s   usercleanend                |; continue processing
usercleanCR:
    move.b  #0,%d0                      |; convert CR to null terminator
    bra.s   usercleanend                |; continue processing


|;******** Prompt user to confirm input
userconfirm:
    lea     %pc@(strConfirm1),%a4       |; get pointer to confirmation header
    callSYS trapPutString               |; and print it
    lea     %a6@(LNBUFF),%a4            |; get pointer to user string
    move.b  #0,%a4@(ULENMAX)            |; force null terminator at end of string
    callSYS trapPutString               |; print user string
userconfirmloop:
    callSYS trapNewLine                 |; print newline
    lea     %pc@(strConfirm2),%a4       |; get pointer to confirmation
    callSYS trapPutString               |; and print it
    callSYS trapGetChar                 |; get character from terminal
    andi.b  #0b01011111,%d0             |; make sure it's upper case
    cmpi.b  #'Y',%d0                    |; did user press Y?
    beq.s   startPrint                  |; if yes, then start printing
    cmpi.b  #'N',%d0                    |; did user press N?
    beq     userprompt                  |; if yes, then start over
    bra.s   userconfirmloop             |; else, ask again for confirmation


|;******** Start printing
startPrint:
    |; ok, here's where the fun begins. we need to open communication with the
    |; printer, configure it the way we want, send the graphical header data,
    |; print the user string, eject the current page, then clean up
    callSYS trapNewLine
    lea     %pc@(strPrinting),%a4 
    callSYS trapPutString

printHeader:
    |; start by setting up the printer for printing 72dpi bitmaps
    lea     %pc@(strPrintSetupBitmap),%a0
    bsr     printerPutStr

    lea     %pc@(strPrintingBitmap),%a4
    callSYS trapPutString
    |; now start printing the header bitmap
        |;    printHeader()
        |;    {
        |;        int height = _PRINTHEADERHEIGHT;                      // %d1
        |;        int width  = _PRINTHEADERWIDTH;                       // %d2
        |;        char * pImgData = _PRINTHEADERSTART;                  // %a1
        |;        for(y=0; y<height; y++)                               // %d3
        |;        {
        |;            printerPutStr(_PRINTHEADERGRAPHDATASTR);
        |;            for(x=0; x<width; x++)                            // %d4
        |;            {
        |;                printerPutChar(pImgData++);
        |;            }
        |;            // CR/LF after each line of bitmap data
        |;            printerPutChar(0x0D);
        |;            printerPutChar(0x0A);
        |;        }
        |;    }
    move.w  %pc@(printHeaderHeight),%d1 |; int height = _PRINTHEADERHEIGHT;
    move.w  %pc@(printHeaderWidth),%d2  |; int width  = _PRINTHEADERWIDTH;
    lea     %pc@(printHeaderStart),%a1  |; char *pImgData = _PRINTHEADERSTART;
    eor.w   %d3,%d3                     |;  y=0;
printHeaderLpY:
    cmp.w   %d1,%d3                     |;  y<height?
    bge.s   printHeaderLpYEnd           |; if true, exit Y loop
    |; print the bitmap data line header
    lea     %pc@(printHeaderGraphicDataString),%a0
    bsr     printerPutStr               |;  printerPutStr(_PRINTHEADERGRAPHDATASTR);
    eor.w   %d4,%d4                     |;  x=0;
printHeaderLpX:
    cmp.w   %d2,%d4                     |;  x<width?
    bge.s   printHeaderLpXEnd           |; if true, exit X loop
    move.b  %a1@+,%d0                   |; get next image data byte
    bsr     printerPutChar              |; printerPutChar(pImgData++);
    addq.w  #1,%d4                      |; x++
    bra.s   printHeaderLpX              |; continue x loop
printHeaderLpXEnd:
    move.b  #0x0D,%d0                   |; printerPutChar(0x0D);
    bsr     printerPutChar              |;
    move.b  #0x0A,%d0                   |; printerPutChar(0x0A);
    bsr     printerPutChar              |;
    addq.w  #1,%d3                      |; y++
    bra.s   printHeaderLpY              |; continue Y loop
printHeaderLpYEnd:
    |; done with printing bitmap image data
    

printUser:
    |; start by setting up the printer for text mode
    lea     %pc@(strPrintSetupText),%a0
    bsr     printerPutStr
    |; send a couple newlines to put some space between header & name
    move.b  #0x0D,%d0                   |; printerPutChar(0x0D);
    bsr     printerPutChar
    move.b  #0x0A,%d0                   |; printerPutChar(0x0A);
    bsr     printerPutChar
    move.b  #0x0D,%d0                   |; printerPutChar(0x0D);
    bsr     printerPutChar
    move.b  #0x0A,%d0                   |; printerPutChar(0x0A);
    bsr     printerPutChar

    lea     %pc@(strPrintingName),%a4
    callSYS trapPutString

    |; now start printing the user string
        |;    void printUser(char * uName)
        |;    {
        |;        void *pTbl = _ASCIIALPHATABLE;                                  // pTbl:    A1
        |;        for(int row=0; row<8; row++)                                    // row:     D1
        |;        {
        |;            char *pName = uName;                                        // pName:   A2
        |;            char c = *pName++;                                          // c:       D2
        |;            while(c != 0)
        |;            {
        |;                char *pFontData = *(pTbl + (c << 2) + (row << 3));      // pFontData: A3
        |;                for(int col=0; col<8; col++)                            // col:     D3
        |;                {
        |;                    char p = *pFontData++;                              // p:       D0
        |;                    printerPutChar(p);
        |;                }
        |;                c = *uName++;
        |;            }
        |;            // at the end of the row, print CR/LF
        |;            printerPutChar(0x0D);
        |;            printerPutChar(0x0A);
        |;        }
        |;    }
|; for(int row=0; row<8; row++){
    eor.w   %d1,%d1                     |; int row=0
printUserLpRow:
    cmpi.w  #8,%d1                      |; row<8;
    bge.s   printUserLpRowEnd
    lea     %a6@(LNBUFF),%a2            |; char *pName = uName;
    move.b  %a2@+,%d2                   |; char c = *pName++;
|; while(c != 0){
printUserLpWhile:
    cmpi.b  #0,%d2                      |; while(c != 0)
    beq.s   printUserLpWhileEnd

    |; char *pFontData = *(pTbl + (c << 2) + (row << 3));
    move.w  %d1,%d4                     |; (row << 3)
    lsl.w   #3,%d4
    
    eor.w   %d5,%d5                     |; (c << 2)
    move.b  %d2,%d5
    lsl.w   #2,%d5

    lea     %pc@(asciiAlphaTable),%a3   |; get pointer to top of lookup table
    movea.l %a3@(%d5.w),%a3             |; use shifted c to get entry from table
                                            |; this is a pointer to the start
                                            |; of font data for the character
    lea     %a3@(%d4.w),%a3             |; add the shifted row to get pointer
                                            |; to the character data for the
                                            |; row we're currently printing

|; for(int col=0; col<8; col++){
    eor.w   %d3,%d3                     |; int col=0;
printUserLpCol:
    cmpi.w  #8,%d3                      |; col<8;
    bge.s   printUserLpColEnd

    move.b  %a3@+,%d0                   |; char p = *pFontData++;
    bsr     printerPutChar              |; printerPutChar(p);

    addq.w  #1,%d3                      |; col++;
    bra.s   printUserLpCol              |; // continue for Col loop
printUserLpColEnd:
    move.b  %a2@+,%d2                   |; c = *uName++;
    bra.s   printUserLpWhile            |; // continue while loop

printUserLpWhileEnd:
    move.b  #0x0D,%d0                   |; printerPutChar(0x0D);
    bsr     printerPutChar
    move.b  #0x0A,%d0                   |; printerPutChar(0x0A);
    bsr     printerPutChar

    addq.w  #1,%d1                      |; row++;
    bra.s   printUserLpRow              |; // continue for Row loop

printUserLpRowEnd:
    |; and now we're done here. send a form feed to the printer
    move.b  #0x0c,%d0
    bsr     printerPutChar


printCleanup:
    lea     %pc@(strPrintingDone),%a4
    callSYS trapPutString
    callSYS trapNewLine
    callSYS trapNewLine
    bra     namewriter


|; function to send a char (%d0) to the printer
printerPutChar:
    movem.l %a1/%d1,%a7@-               |; save working registers
    lea     spioCOM1,%a1                |; get pointer to aux COM port
printerTxNotReady:
    move.b  %a1@(comRegLSR),%d1         |; get COM port status
    btst    #5,%d1                      |; check if ready to send
    beq     printerTxNotReady           |; loop until ready
|printerNotReady:
|    move.b  %a1@(comRegMSR)             |; get printer status
|    btst    #5,%d1                      |; check if ready to receive
|    beq     printerNotReady             |; loop until ready
printerSendByte:
    move.b  %d0,%a1@(comRegTX)          |; send byte to printer
    movem.l %a7@+,%a1/%d1               |; restore working registers
    rts

|; function to send a null-terminated string at (%a0) to the printer
printerPutStr:
    movem.l %d0,%a7@-                   |; save working register
printerPutStrLp:
    move.b  %a0@+,%d0                   |; fetch next string byte
    cmpi.l  #0,%d0                      |; is it null?
    beq.s   printerPutStrEnd            |; if yes then jump to end
    bsr     printerPutChar              |; else send char to printer
    bra     printerPutStrLp             |; keep going
printerPutStrEnd:
    movem.l %a7@+,%d0                   |; restore working register
    rts



strHeader:
    .ascii  "Wrap030 Namewriter for VCFSW 2023\0"
strNamePrompt:
    .ascii  "What is your name? \0"
strConfirm1:
    .ascii  "Printing Name: \0"
strConfirm2:
    .ascii  "Continue (Y/N)? \0"
strPrinting:
    .ascii  "Printing: \0"
strPrintingBitmap:
    .ascii  "Bitmap ... \0"
strPrintingName:
    .ascii  "Name ... \0"
strPrintingDone:
    .ascii  "Done.\0"
strPrintError:
    .ascii  "Printer timed out. Aborting.\0"


strPrintSetupBitmap:
    dc.b    0x1b,'n'                    |; select 9cpi (72dpi hoz)
    dc.b    0x1b,'T','1','6'            |; select 16/144 line feed (72dpi ver)
    dc.b    0x0d,0x0a                   |; start with CR/LF after configuring
    dc.b    0

strPrintSetupText:
    dc.b    0x1b,'M'                    |; select NLQ font
    dc.b    0x1b,'q'                    |; set hoz to 15cpi
    dc.b    0




    .even
    .include    "Namewriter/asciialpha.s"
    .include    "Namewriter/HeaderImage/Header.s"

