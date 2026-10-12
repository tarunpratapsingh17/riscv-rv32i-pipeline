// crc32.c - bitwise CRC-32 (IEEE 802.3); standard check value for "123456789" is 0xCBF43926
#include "common.h"

static uint32_t crc32(const uint8_t *p, uint32_t len)
{
    uint32_t crc = 0xFFFFFFFFu;
    while (len--) {
        crc ^= *p++;
        for (int b = 0; b < 8; b++)
            crc = (crc >> 1) ^ (0xEDB88320u & -(crc & 1u));
    }
    return ~crc;
}

int main(void)
{
    static const uint8_t msg[] = "123456789";
    uint32_t c = crc32(msg, 9);
    puts_("crc32 = 0x"); put_hex(c); putchar_('\n');
    return (c == 0xCBF43926u) ? 0 : 1;
}
