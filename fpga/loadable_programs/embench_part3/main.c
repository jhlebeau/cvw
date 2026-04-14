#include <stdio.h>

#include "embench_benches.h"
#include "support.h"

int
main (void)
{
  uartInit ();

  printstr ("Running multi Embench suite\n\r\n\r");

  run_picojpeg_benchmark ();
  run_primecount_benchmark ();
  //run_qrduino_benchmark (); //does not work
  run_sglib_combined_benchmark ();
  run_slre_benchmark ();

  printstr ("Finished multi Embench suite\n\r");
  return 0;
}
