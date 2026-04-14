#include <stdio.h>

#include "embench_benches.h"
#include "support.h"

int
main (void)
{
  uartInit ();

  printstr ("Running multi Embench suite\n\r\n\r");

  run_st_benchmark ();
  run_statemate_benchmark ();
  //run_tarfind_benchmark (); //too much ram
  run_ud_benchmark ();
  run_wikisort_benchmark ();

  printstr ("Finished multi Embench suite\n\r");
  return 0;
}
