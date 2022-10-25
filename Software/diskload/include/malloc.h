// this is going to be a very, VERY naive memory allocator.
// we're not going to bother with silly things  usage bitmaps, 
// garbage collection, etc.
// when asked for space we'll give it, and increment a single pointer
// by the amount requested. 
// free() will be very dangerous and just roll back the pointer by the amount
// requested

#include "types.h"
#include "hardware.h"

#ifndef _malloc_naive_h
#define _malloc_naive_h

// here's our primary memory allocation function
void * malloc(uint32_t);

// here's our dangerous memory free function
void free(uint32_t);

// we'll need an initialization routine to establish the base pointer
void minit(void*);

#endif