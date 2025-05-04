#include "fir.h"

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	//initial your fir
  for (int i = 0; i < N; i++){
    inputbuffer[i] = 0;
    outputsignal[i] = 0;
  }
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(){
	initfir();
	//write down your fir
  for (int i = 0; i < N; i++) {
      for (int j = N - 1; j > 0; j--) {
          inputbuffer[j] = inputbuffer[j - 1];
      }
      inputbuffer[0] = inputsignal[i];

      int sum = 0;
      for (int k = 0; k < N; k++) {
          sum += inputbuffer[k] * taps[k];
      }

      outputsignal[i] = sum;
  }

	return outputsignal;
}
		
