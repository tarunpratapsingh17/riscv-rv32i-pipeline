// sort.c - insertion sort of 128 pseudo-random words; checks order and checksum
#include "common.h"

#define N 128
static uint32_t data[N];

int main(void)
{
    uint32_t seed = 12345u, sum_before = 0, sum_after = 0;

    for (int i = 0; i < N; i++) {
        seed = seed * 1103515245u + 12345u;      // LCG (multiply via libgcc)
        data[i] = seed >> 8;
        sum_before += data[i];
    }

    for (int i = 1; i < N; i++) {
        uint32_t key = data[i];
        int j = i - 1;
        while (j >= 0 && data[j] > key) {
            data[j + 1] = data[j];
            j--;
        }
        data[j + 1] = key;
    }

    for (int i = 0; i < N; i++) {
        sum_after += data[i];
        if (i > 0 && data[i - 1] > data[i]) return 1;
    }
    if (sum_before != sum_after) return 2;

    puts_("sorted "); put_dec(N); puts_(" words\n");
    return 0;
}
