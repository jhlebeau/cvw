

int main(void){

  volatile int a = 63;
  unsigned int hi_before;
  unsigned int lo;
  asm volatile ("csrr %0, mcycleh" : "=r" (hi_before));
  asm volatile ("csrr %0, mcycle" : "=r" (lo));
  return lo;
  
}
