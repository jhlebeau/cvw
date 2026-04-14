#ifndef MULTI_EMBENCH_COMMON_H
#define MULTI_EMBENCH_COMMON_H

#include <stdint.h>

#include "support.h"

#ifndef CPU_MHZ
#define CPU_MHZ 20
#endif

uint64_t embench_read_mcycle64 (void);
void embench_report_result (const char *name, int correct, uint64_t cycles);

#endif
