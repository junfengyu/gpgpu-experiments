#include "cplx.c"

/*
 // The fft "butterfly" stage merges two contiguous halves.
 //
 // Here, 'i' is the size of a half.
 //
 // For each 'i', we need to compute the index at which
 //   our thread will operate.
 //
 // for i = 1:
 // -+-+-+-+
 // 0 1 2 3
 //
 // for i = 2:
 // --++--++
 // 01  23
 //
 // for i = 4:
 // ----++++
 // 0123
 //
 // ... and in the general case:
 //
 // ---- (i) ----++++ (i) ++++---- (i) ----++++ (i) ++++ ...
 // 0123 .....i-1             i ...    2i-1
 //
 // so from the diagram above we can see that: idx = 2*i*(k/i) + (k % i)
 //
 // and by definition of the modulo: k%i = k - i*(k/i)
 // so we can write: idx = i*(k/i) + k
 */

// This algorithm has the nice property that there is no "branch divergence":
// all threads have the same control flow. So it seems it's the perfect candidate
// for running on a GPU, because the parallelization is massive.
__kernel void kernel_func(__global const float *input, __global const struct cplx *twiddle, __global struct cplx *output) {
  
  // Get the index of the current element to be processed
  int const k = get_global_id(0); // we use a single dimension hence we pass 0
  
  output[2*k]   = complexFromReal(input[2*k]);
  output[2*k+1] = complexFromReal(input[2*k+1]);

  barrier(CLK_GLOBAL_MEM_FENCE);
  
  int const n_global_butterflies = get_global_size(0);

  for(int i=1; i<=n_global_butterflies; i <<= 1) {
    int const tmp = i*(k/i);
    int const idx = tmp + k;

    //assert(idx+i < Sz);
    
    int const ri = k - tmp;
    int const tIdx = ri*(n_global_butterflies/i);
    butterfly_global(output+idx, i, twiddle[tIdx]);

    barrier(CLK_GLOBAL_MEM_FENCE);
  }
}
