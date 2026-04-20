#!/usr/bin/env python3

import argparse
import json
import re
import sys
from pathlib import Path

DEFAULT_CPU_MHZ = 20
USEC_PER_MSEC = 1000

REPO_ROOT = Path(__file__).resolve().parents[2]
BASELINE_PATH = REPO_ROOT / "addins" / "embench-iot" / "baseline-data" / "speed.json"
EMBENCH_SRC_ROOT = REPO_ROOT / "addins" / "embench-iot" / "src"


def load_baselines(path: Path) -> dict:
    with path.open() as f:
        return json.load(f)


def find_official_scale_factor(benchmark: str) -> tuple[int, Path]:
    bench_dir = EMBENCH_SRC_ROOT / benchmark
    if not bench_dir.is_dir():
        raise FileNotFoundError(f"Benchmark source directory not found: {bench_dir}")

    for source in sorted(bench_dir.glob("*.c")):
        text = source.read_text()
        match = re.search(r"#define\s+LOCAL_SCALE_FACTOR\s+(\d+)", text)
        if match:
            return int(match.group(1)), source

    raise ValueError(
        f"Could not find LOCAL_SCALE_FACTOR in sources under {bench_dir}"
    )


def compute_score(
    baseline_ms: float,
    cycles: int,
    cpu_mhz: int,
    measured_scale_factor: int,
    official_scale_factor: int,
) -> float:
    adjusted_cycles = cycles * official_scale_factor / measured_scale_factor
    measured_ms = adjusted_cycles / (cpu_mhz * USEC_PER_MSEC)
    return baseline_ms / measured_ms


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Compute an Embench relative speed score from a benchmark name and cycle count."
    )
    parser.add_argument("benchmark", help="Embench benchmark name, e.g. crc32 or nbody")
    parser.add_argument("cycles", type=int, help="Measured cycle count")
    parser.add_argument(
        "--cpu-mhz",
        type=int,
        default=DEFAULT_CPU_MHZ,
        help=f"CPU clock in MHz used for the measurement (default: {DEFAULT_CPU_MHZ})",
    )
    parser.add_argument(
        "--local-scale-factor",
        type=int,
        default=None,
        help=(
            "LOCAL_SCALE_FACTOR used by the measured program "
            "(default: use the benchmark's recommended Embench value)"
        ),
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.cycles <= 0:
        parser.error("cycles must be a positive integer")
    if args.cpu_mhz <= 0:
        parser.error("--cpu-mhz must be a positive integer")
    baselines = load_baselines(BASELINE_PATH)
    if args.benchmark not in baselines:
        known = ", ".join(sorted(baselines))
        print(f"Unknown benchmark '{args.benchmark}'. Known benchmarks: {known}", file=sys.stderr)
        return 1

    try:
        official_scale_factor, source_path = find_official_scale_factor(args.benchmark)
    except (FileNotFoundError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1

    measured_scale_factor = args.local_scale_factor
    if measured_scale_factor is None:
        measured_scale_factor = official_scale_factor
    elif measured_scale_factor <= 0:
        parser.error("--local-scale-factor must be a positive integer")

    baseline_ms = baselines[args.benchmark]
    score = compute_score(
        baseline_ms=baseline_ms,
        cycles=args.cycles,
        cpu_mhz=args.cpu_mhz,
        measured_scale_factor=measured_scale_factor,
        official_scale_factor=official_scale_factor,
    )

    print(f"Benchmark: {args.benchmark}")
    print(f"Cycle count: {args.cycles}")
    print(f"CPU_MHZ: {args.cpu_mhz}")
    print(f"Measured LOCAL_SCALE_FACTOR: {measured_scale_factor}")
    print(f"Official LOCAL_SCALE_FACTOR: {official_scale_factor}")
    print(f"Official source: {source_path.relative_to(REPO_ROOT)}")
    print(f"Baseline time (ms): {baseline_ms}")
    print(f"Embench relative speed: {score:.6f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
