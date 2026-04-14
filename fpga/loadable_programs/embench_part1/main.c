#include <stdio.h>

#include "embench_benches.h"
#include "support.h"

int
main (void)
{
  uartInit ();

  printstr ("Running multi Embench suite\n\r\n\r");

  run_aha_mont64_benchmark ();
  run_crc32_benchmark ();
  run_cubic_benchmark ();
  run_edn_benchmark ();
  //run_huffbench_benchmark (); //too much ram
  run_matmult_int_benchmark ();

  printstr ("Finished multi Embench suite\n\r");
  return 0;
}
