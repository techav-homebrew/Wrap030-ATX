#include "malloc.h"

// this pointer will keep track of where we are allocating
void * _memPtr __attribute__ ((section (".bss")));

// here's our very basic memory allocation routine that only keeps track of
// requests for allocation, and has no way to free used memory.
// returns a null pointer in the event heap overflows into the stack
void * malloc(uint32_t size)
{
    // start by initializing a pointer at our current memory location
    void *retPtr = _memPtr;

    // check that we're not about to crash into the stack
    // we'll take the easy route and check the address of the local variable
    // we just created
    if((uint32_t)&retPtr <= (uint32_t)(_memPtr+size))
    {
        // heap overflow error. return a null pointer
        retPtr = 0;
    }
    else
    {
        // increment our primary pointer
        _memPtr += size;
    }

    // and return the pointer we've created
    return retPtr;
}

// here's our very, very basic memory free routine.
// all it does is roll back the primary memory pointer by the amount requested.
// if it is to be used at all, it should be paired with malloc() as though
// pushing and popping from a stack.
void free(uint32_t size)
{
    if((uint32_t)(_memPtr - size) < (uint32_t)(heapStart))
    {
        // big problem .. we're about to crash into vector table
        _memPtr = (void*)heapStart;
    }
    else
    {
        _memPtr = _memPtr - size;
    }
}

// we'll need an initialization routine to establish the base pointer
void minit(void *ptrInit)
{
    _memPtr = ptrInit;
}