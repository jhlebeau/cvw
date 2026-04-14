#include <stdio.h>

#include "embench_benches.h"
#include "support.h"

int
main (void)
{
  uartInit ();

  printstr ("Running multi Embench suite\n\r\n\r");

  run_md5sum_benchmark ();
  run_minver_benchmark ();
  run_nbody_benchmark ();
  run_nettle_aes_benchmark ();
  run_nettle_sha256_benchmark ();
  run_nsichneu_benchmark ();

  printstr ("Finished multi Embench suite\n\r");
  return 0;
}
