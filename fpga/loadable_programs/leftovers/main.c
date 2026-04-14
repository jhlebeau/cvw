#include <stdio.h>

#include "embench_benches.h"
#include "support.h"

int
main (void)
{
  uartInit ();

  printstr ("Running multi Embench suite\n\r\n\r");

  run_matmult_int_benchmark ();
  // run_qrduino_benchmark (); run issue
  run_sglib_combined_benchmark ();
  run_slre_benchmark ();
  run_ud_benchmark ();
  run_wikisort_benchmark ();

  printstr ("Finished multi Embench suite\n\r");
  return 0;
}
