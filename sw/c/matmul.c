// matmul.c - 8x8 integer matrix multiply (RV32I has no MUL: uses libgcc __mulsi3)
// Self-check: the sum of all elements of A*B equals sum_k colsum(A)[k] * rowsum(B)[k]
#include "common.h"

#define N 8
static int32_t A[N][N], B[N][N], C[N][N];

int main(void)
{
    int32_t v = 3;
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            v = (v * 7 + 11) % 97 - 48;          // small signed values
            A[i][j] = v;
            B[j][i] = v / 2 + 1;
        }

    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            int32_t acc = 0;
            for (int k = 0; k < N; k++)
                acc += A[i][k] * B[k][j];
            C[i][j] = acc;
        }

    int32_t total = 0, expect = 0;
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++)
            total += C[i][j];

    for (int k = 0; k < N; k++) {
        int32_t colA = 0, rowB = 0;
        for (int i = 0; i < N; i++) colA += A[i][k];
        for (int j = 0; j < N; j++) rowB += B[k][j];
        expect += colA * rowB;
    }

    puts_("matmul checksum = "); put_hex((uint32_t)total); putchar_('\n');
    return (total == expect) ? 0 : 1;
}
