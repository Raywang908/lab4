#include "fir.h"
#include <defs.h>

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	//initial your fir
	//reg_fir_x = 0;
	reg_fir_y = 0;
	write_reg(reg_data_length, data_length);
	write_reg(reg_tap_number, N);
	for (int i = 0; i < N; i = i + 1){
		write_reg((reg_fir_coeff + (4 * i)), taps[i]);
	}
 	for (int i = 0; i < N; i = i + 1){
		reg_mprj_datal = (read_reg(reg_fir_coeff + (4 * i)) << 16);
	}
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(){
	//write down your fir
	reg_mprj_datal = 0x00A50000;
	initfir();
	// polling
	while(1) {
		if((read_reg(reg_fir_control) & (1 << 2)) == 0x00000004){
			write_reg(reg_fir_control, 1);
			break;
		} 
	}

	for(int i = 0; i < data_length; i = i + 1){
		//reg_fir_x = i;
		write_reg(fir_x, i);
		reg_fir_y = read_reg(fir_y);
    //reg_mprj_datal = reg_fir_y << 16;
	}

	reg_mprj_datal = (reg_fir_y << 24) | (0x005A0000);
	reg_mprj_datal = 0x00A50000;
	while(1) {
		if((read_reg(reg_fir_control) & (1 << 2)) == 0x00000004){
			write_reg(reg_fir_control, 1);
			break;
		} 
	}

	for(int i = 0; i < data_length; i = i + 1){
		//reg_fir_x = i;
		write_reg(fir_x, i);
		reg_fir_y = read_reg(fir_y);
    reg_mprj_datal = reg_fir_y << 16;
	}
	reg_mprj_datal = (reg_fir_y << 24) | (0x005A0000);
	reg_mprj_datal = 0x00A50000;
	while(1) {
		if((read_reg(reg_fir_control) & (1 << 2)) == 0x00000004){
			write_reg(reg_fir_control, 1);
			break;
		} 
	}

	for(int i = 0; i < data_length; i = i + 1){
		//reg_fir_x = i;
		write_reg(fir_x, i);
		reg_fir_y = read_reg(fir_y);
    reg_mprj_datal = reg_fir_y << 16;
	}
	reg_mprj_datal = (reg_fir_y << 24) | (0x005A0000);

	return outputsignal;
}
		
