/* BEEBS qrduino benchmark

   This version, copyright (C) 2014-2019 Embecosm Limited and University of
   Bristol

   Contributor James Pallister <james.pallister@bristol.ac.uk>
   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   This file is part of Embench and was formerly part of the Bristol/Embecosm
   Embedded Benchmark Suite.

   SPDX-License-Identifier: GPL-3.0-or-later

   Original code from: https://github.com/tz1/qrduino */

#include "embench_common.h"
#include "qrencode.h"

#include <string.h>

/* This scale factor will be changed to equalise the runtime of the
   benchmarks. */
#define LOCAL_SCALE_FACTOR 5

/* BEEBS heap is just an array */

#define HEAP_SIZE 8192
static char heap[HEAP_SIZE];

static const char *encode;
static int size;

static int qrduino_benchmark_body (int rpt);

static void
qrduino_warm_caches (int heat)
{
  int res = qrduino_benchmark_body (heat);

  return;
}


static int
qrduino_benchmark (void)
{
  return qrduino_benchmark_body (LOCAL_SCALE_FACTOR * CPU_MHZ);
}


static int __attribute__ ((noinline))
qrduino_benchmark_body (int rpt)
{
  static const char *in_encode = "http://www.mageec.com";
  int i;

  for (i = 0; i < rpt; i++)
    {
      encode = in_encode;
      size = 22;
      init_heap_beebs ((void *) heap, HEAP_SIZE);

      initeccsize (1, size);

      memcpy (strinbuf, encode, size);
      strinbuf[size] = '\0';

      initframe ();
      qrencode ();
      freeframe ();
      freeecc ();
    }

  return 0;
}

static void
qrduino_initialise_benchmark (void)
{
}

static int
verify_qrduino_benchmark (int unused)
{
  unsigned char expected[22] = {
    254, 101, 63, 128, 130, 110, 160, 128, 186, 65, 46,
    128, 186, 38, 46, 128, 186, 9, 174, 128, 130, 20
  };

  return (0 == memcmp (strinbuf, expected, 22 * sizeof (strinbuf[0])))
    && check_heap_beebs ((void *) heap);
}

void
run_qrduino_benchmark (void)
{
  uint64_t start_cycles;
  uint64_t stop_cycles;
  int res;

  qrduino_initialise_benchmark ();
  qrduino_warm_caches (1);

  start_cycles = embench_read_mcycle64 ();
  res = qrduino_benchmark ();
  stop_cycles = embench_read_mcycle64 ();

  embench_report_result ("Qrduino", verify_qrduino_benchmark (res),
                         stop_cycles - start_cycles);
}


/*
   Local Variables:
   mode: C
   c-file-style: "gnu"
   End:
*/
