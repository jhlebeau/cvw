#!/bin/bash
#######################################################################
# splitfile.sh
#
# Written: Jacob Pease jacob.pease@okstate.edu 7/22/2024
#
# Purpose: Used to split boot.mem into two sections for FPGA
#
#
#
# A component of the Wally configurable RISC-V project.
#
# Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the
# “License”); you may not use this file except in compliance with the
# License, or, at your option, the Apache License version 2.0. You
# may obtain a copy of the License at
#
# https://solderpad.org/licenses/SHL-2.1/
#
# Unless required by applicable law or agreed to in writing, any work
# distributed under the License is distributed on an “AS IS” BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.
######################################################################


# Acquired from here.
# https:##stackoverflow.com#questions#3066948#how-to-file-split-at-a-line-number
set -euo pipefail

file_name=${1:-}
if [[ -z "${file_name}" ]]; then
  echo "Usage: $0 <memfile> [linker_script] [K_override]" >&2
  exit 1
fi

linker_script=${2:-linker1000.x}
K_override=${3:-}

if [[ ! -f "${file_name}" ]]; then
  echo "Error: input file not found: ${file_name}" >&2
  exit 1
fi

# Compute K from linker script unless caller explicitly overrides.
# K = (DTIM_BASE - IROM_BASE) / 4  (word-addressed hex lines, 32-bit words)
# Prefer IROM_BASE for FPGA IROM flows; keep BOOTROM_BASE fallback for compatibility.
if [[ -n "${K_override}" ]]; then
  K=${K_override}
else
  if [[ ! -f "${linker_script}" ]]; then
    echo "Error: linker script not found: ${linker_script}" >&2
    exit 1
  fi

  irom_base_hex=$(sed -n 's/^[[:space:]]*IROM_BASE[[:space:]]*=[[:space:]]*0x\([0-9A-Fa-f]\+\)[[:space:]]*;.*/\1/p' "${linker_script}" | head -n1)
  bootrom_base_hex=$(sed -n 's/^[[:space:]]*BOOTROM_BASE[[:space:]]*=[[:space:]]*0x\([0-9A-Fa-f]\+\)[[:space:]]*;.*/\1/p' "${linker_script}" | head -n1)
  dtim_base_hex=$(sed -n 's/^[[:space:]]*DTIM_BASE[[:space:]]*=[[:space:]]*0x\([0-9A-Fa-f]\+\)[[:space:]]*;.*/\1/p' "${linker_script}" | head -n1)

  if [[ -n "${irom_base_hex}" ]]; then
    rom_base_hex="${irom_base_hex}"
    rom_base_name="IROM_BASE"
  elif [[ -n "${bootrom_base_hex}" ]]; then
    rom_base_hex="${bootrom_base_hex}"
    rom_base_name="BOOTROM_BASE"
  else
    echo "Error: could not parse IROM_BASE (or BOOTROM_BASE fallback) from ${linker_script}" >&2
    exit 1
  fi

  if [[ -z "${dtim_base_hex}" ]]; then
    echo "Error: could not parse DTIM_BASE from ${linker_script}" >&2
    exit 1
  fi

  rom_base=$((16#${rom_base_hex}))
  dtim_base=$((16#${dtim_base_hex}))

  if (( dtim_base <= rom_base )); then
    echo "Error: DTIM_BASE (0x${dtim_base_hex}) must be greater than ${rom_base_name} (0x${rom_base_hex})" >&2
    exit 1
  fi
  if (((dtim_base - rom_base) % 4 != 0)); then
    echo "Error: DTIM_BASE - ${rom_base_name} must be a multiple of 4 bytes" >&2
    exit 1
  fi

  K=$(((dtim_base - rom_base) / 4))
fi

# line count (N):
N=$(wc -l < "$file_name")

# length of the bottom file:
L=$((N - K))
if (( L < 0 )); then
  L=0
fi

# create the top of file:
head -n "$K" "$file_name" > boot.mem

# create bottom of file:
if (( L > 0 )); then
  tail -n "$L" "$file_name" > data.mem
else
  : > data.mem
fi

echo "splitfile.sh: K=${K} (from ${linker_script}), N=${N}, data_lines=${L}" >&2
