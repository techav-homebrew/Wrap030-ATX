

.text


.globl  endianSwap16
.globl  endianSwap32


# extern uint16_t endianswap16(uint16_t)
endianSwap16:
    move.w  -4(%sp),%d0         | get parameter pushed to stack
    ror.w   #8,%d0              | rotate bytes
    rts                         | return the value in D0





# extern uint32_t endianSwap32(uint32_t)
endianSwap32:
    move.l  -4(%sp),%d0         | get parameter pushed to stack
    ror.w   #8,%d0              | rotate the first word
    swap    %d0                 | swap words
    ror.w   #8,%d0              | rotate the second word
    rts                         | return value in D0

