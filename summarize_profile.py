#!/usr/bin/env python3
"""
summarize_profile.py — computes median core_ms per configuration from a
profiling CSV produced by profile_serial.sh / profile_parallel.sh.

Usage: python3 summarize_profile.py output/profile/serial_profile.csv
"""

import csv
import statistics
import sys
from collections import defaultdict

def main():
    path = sys.argv[1]
    groups = defaultdict(list)
    meta = {}

    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            key = row["label"]
            groups[key].append(float(row["core_ms"]))
            meta[key] = row

    print(f"{'label':28s} {'rows':>5s} {'cols':>5s} {'mode':10s} {'landscape':10s} "
          f"{'reps':>5s} {'timesteps':>10s} {'median_ms':>12s}")

    for key in sorted(groups):
        vals = groups[key]
        m = meta[key]
        median_ms = statistics.median(vals)
        print(f"{key:28s} {m['rows']:>5s} {m['columns']:>5s} {m['mode']:10s} "
              f"{m['landscape']:10s} {len(vals):>5d} {m['timesteps']:>10s} "
              f"{median_ms:>12.2f}")

if __name__ == "__main__":
    main()