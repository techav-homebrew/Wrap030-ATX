
    .extern _stackstart
    .extern _start

.section    .vector

# start with the initial vector table
    .long   _stackstart
    .rept   255
    .long   _start
    .endr

