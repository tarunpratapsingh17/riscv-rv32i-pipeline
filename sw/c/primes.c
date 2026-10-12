// primes.c - sieve of Eratosthenes, byte loads/stores; there are 168 primes below 1000
#include "common.h"

#define LIMIT 1000
static uint8_t composite[LIMIT];

int main(void)
{
    uint32_t count = 0;
    for (uint32_t i = 2; i < LIMIT; i++) {
        if (!composite[i]) {
            count++;
            for (uint32_t j = i + i; j < LIMIT; j += i)
                composite[j] = 1;
        }
    }
    puts_("primes below 1000: "); put_dec(count); putchar_('\n');
    return (count == 168) ? 0 : 1;
}
