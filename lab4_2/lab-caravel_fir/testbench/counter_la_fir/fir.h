#ifndef __FIR_H__
#define __FIR_H__

#include <stdint.h>

#define N 11
#define data_length 64

// MMIO register addresses（保留變數名稱）
#define reg_fir_control  0x30000000
#define reg_data_length  0x30000010
#define reg_tap_number   0x30000014
#define fir_x            0x30000040
#define fir_y            0x30000044
#define reg_fir_coeff    0x30000080  // base address for tap coefficients

// MMIO access macros
#define write_reg(addr, data) (*(volatile uint32_t*)(addr) = (data))
#define read_reg(addr)        (*(volatile uint32_t*)(addr))

// Data buffers
int taps[N] = {0, -10, -9, 23, 56, 63, 56, 23, -9, -10, 0};
int inputbuffer[N];
int outputsignal[N];
//int reg_fir_x;
int reg_fir_y;

#endif


/*
62 * -10 + 61 * -9 + 60 * 23 + 59 * 56 + 58 * 63 + 57 * 56 + 56 * 23 + 55 * -9 + 54 * -10 =  
= 10614
= 0x2976 
*/
