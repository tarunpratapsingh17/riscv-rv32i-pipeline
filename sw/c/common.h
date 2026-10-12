// common.h - tiny bare-metal helpers for test programs
#ifndef COMMON_H
#define COMMON_H

#include <stdint.h>
#include <stddef.h>

#define PUTCHAR_ADDR ((volatile uint32_t *)0x00010004)

static inline void putchar_(char c) { *PUTCHAR_ADDR = (uint32_t)c; }

static inline void puts_(const char *s)
{
    while (*s) putchar_(*s++);
}

static inline void put_dec(uint32_t v)
{
    char buf[11];
    int i = 0;
    if (v == 0) { putchar_('0'); return; }
    while (v) { buf[i++] = (char)('0' + v % 10); v /= 10; }
    while (i) putchar_(buf[--i]);
}

static inline void put_hex(uint32_t v)
{
    for (int i = 28; i >= 0; i -= 4) {
        uint32_t d = (v >> i) & 0xF;
        putchar_((char)(d < 10 ? '0' + d : 'a' + d - 10));
    }
}

// gcc may emit calls to these even in freestanding code
void *memset(void *dst, int c, size_t n);
void *memcpy(void *dst, const void *src, size_t n);

#endif
