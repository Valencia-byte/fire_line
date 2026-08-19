#!/usr/bin/env python3
"""
compute_speedup.py — median core_ms per (program, size), then
speedup = median_serial / median_parallel for each grid size.

Usage: python3 compute_speedup.py output/profile/grid_size_benchmark.csv
"""
import csv
import statistics
import sys
from collections import defaultdict

def main():
    path = sys.argv[1]
    groups = defaultdict(list)

    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            key = (row["program"], int(row["size"]))
            groups[key].append(float(row["core_ms"]))

    sizes = sorted({size for (_, size) in groups})

    print(f"{'size':>6s} {'serial_reps':>11s} {'serial_median_ms':>17s} "
          f"{'parallel_reps':>13s} {'parallel_median_ms':>19s} {'speedup':>8s}")

    for size in sizes:
        serial_vals = groups.get(("serial", size), [])
        parallel_vals = groups.get(("parallel", size), [])
        if not serial_vals or not parallel_vals:
            print(f"{size:>6d}  missing data (serial={len(serial_vals)}, parallel={len(parallel_vals)})")
            continue

        serial_median = statistics.median(serial_vals)
        parallel_median = statistics.median(parallel_vals)
        speedup = serial_median / parallel_median

        print(f"{size:>6d} {len(serial_vals):>11d} {serial_median:>17.2f} "
              f"{len(parallel_vals):>13d} {parallel_median:>19.2f} {speedup:>8.2f}")

if __name__ == "__main__":
    main()