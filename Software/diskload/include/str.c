
#include "str.h"

// Compares two null-terminated strings
// Returns true if strings match
// Returns false if no match
Boolean strcmp(unsigned char* str1, unsigned char* str2)
{
    uint32_t i;

    // if both strings are empty, consider them a match
    if(*str1 == 0 && *str2 == 0) return true;
    
    for(i=0; i<strlen(str1); i++)
    {
        if(*(str1+i) == *(str2+i)) continue;    // strings match so far
        else if(*(str2+i) == 0) return false;   // str2 has ended early
        else return false;                      // they don't match here
    }
    // if we've made it out of the loop, then the strings match.
    return true;
}

// returns length of string as number of bytes
uint32_t strlen(unsigned char* str)
{
    uint32_t len = 1;
    unsigned char *ptrStr = str;
    if(*ptrStr == 0) return 0;
    while(*ptrStr != 0)
    {
        len++;
        ptrStr++;
    }
    return len;
}

// Copies null-terminated str1 into str2
// Has no way to compare bounds beyond the null-termination of str1
void strcopy(unsigned char* str1, unsigned char* str2)
{
    unsigned char* ptrStr1 = str1;
    unsigned char* ptrStr2 = str2;
    do
    {
        *ptrStr2 = *ptrStr1;
        ptrStr1++;
        ptrStr2++;
    } while (*ptrStr1 != 0);
}


// Concatenates two strings
// Copies str2 to the end of str1 and saves to str1
void strconcat(unsigned char* str1, unsigned char* str2)
{
    unsigned char* ptrStr1 = str1;
    unsigned char* ptrStr2 = str2;

    // find end of str1
    while(*ptrStr1 != 0)
    {
        ptrStr1++;
    }

    // copy str2 to its end, including null terminator
    do
    {
        *ptrStr1 = *ptrStr2;
        ptrStr1++;
        ptrStr2++;
    } while (ptrStr2 != 0);
}