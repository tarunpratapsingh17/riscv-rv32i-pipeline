// fib.c - recursive and iterative Fibonacci; stresses calls, returns and the stack
#include "common.h"

static uint32_t fib_rec(uint32_t n)
{
    return (n < 2) ? n : fib_rec(n - 1) + fib_rec(n - 2);
}

static uint32_t fib_iter(uint32_t n)
{
    uint32_t a = 0, b = 1;
    for (uint32_t i = 0; i < n; i++) {
        uint32_t t = a + b;
        a = b;
        b = t;
    }
    return a;
}

int main(void)
{
    uint32_t r = fib_rec(18);
    uint32_t it = fib_iter(18);
    puts_("fib(18) = "); put_dec(r); putchar_('\n');
    if (r != 2584 || it != 2584) return 1;
    if (fib_iter(40) != 102334155u) return 2;
    return 0;
}
