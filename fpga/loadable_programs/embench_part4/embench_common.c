#include "embench_common.h"

uint64_t
embench_read_mcycle64 (void)
{
  uint32_t hi_before;
  uint32_t lo;
  uint32_t hi_after;

  do
    {
      asm volatile ("csrr %0, mcycleh" : "=r" (hi_before));
      asm volatile ("csrr %0, mcycle" : "=r" (lo));
      asm volatile ("csrr %0, mcycleh" : "=r" (hi_after));
    }
  while (hi_before != hi_after);

  return ((uint64_t) hi_before << 32) | lo;
}

void
embench_report_result (const char *name, int correct, uint64_t cycles)
{
  printstr (name);
  printstr (correct ? " computed correctly\n\r" : " computed wrong\n\r");

  if (!correct)
    return;

  printstr ("Benchmark cycles: 0x");
  printhex (cycles);
  printstr ("\n\r");
  printstr ("\n\r\n\r");
}
