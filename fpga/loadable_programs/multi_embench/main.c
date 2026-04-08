#include <stdio.h>

#include "embench_benches.h"
#include "support.h"

int
main (void)
{
  uartInit ();

  printstr ("Running multi Embench suite\n\r\n\r");

  run_crc32_benchmark ();
  run_nbody_benchmark ();
  run_cubic_benchmark ();

  printstr ("Finished multi Embench suite\n\r");
  return 0;
}
