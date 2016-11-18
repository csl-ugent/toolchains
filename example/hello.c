#include <stdio.h>

int globalvar = 0xFFFAAA;

double test_float(double arg) {
    printf("Float: %f", arg);
}

int main ()
{
    asm volatile ("nop");
    int b = globalvar;
    printf("Hello World.");
    return 0;
}

