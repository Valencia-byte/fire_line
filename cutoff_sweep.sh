#!/usr/bin/env bash
#
# cutoff_sweep.sh — sweeps the sequential cutoff for FirelineParallel at a
# fixed, representative configuration (800x800 wildfire, mixed, seed 42),
# using the JVM's default ForkJoinPool parallelism (not overridden here,
# so cutoff is the only thing varying between runs).
#
# First, coarse pass: wide range of cutoff values, 3 repetitions each, to
# find roughly where the optimum sits before a tighter, more-repeated
# sweep around that region.
#
# Usage: ./cutoff_sweep.sh   (run from the project root, after `make all`)
# Output: output/profile/cutoff_sweep.csv

set -u
BIN=bin
OUT=output/profile
mkdir -p "$OUT"

CSV="$OUT/cutoff_sweep.csv"
echo "cutoff,repetition,timesteps,converged,core_ms,parallelism" > "$CSV"

REPS=3
ROWS=800
COLS=800
SEED=42
MODE=wildfire
LANDSCAPE=mixed

for cutoff in 10 50 200 1000 5000 20000 80000 320000 700000; do
    for rep in $(seq 1 $REPS); do
        prefix="$OUT/cutoff_${cutoff}_rep${rep}"
        java -Dfireline.cutoff="$cutoff" \
             -cp "$BIN" FirelineParallel "$ROWS" "$COLS" "$SEED" "$MODE" "$prefix" 50000 0.05 "$LANDSCAPE" \
            > "${prefix}.log" 2>&1

        timesteps=$(grep "^Timesteps completed:" "${prefix}.log" | awk '{print $3}')
        converged=$(grep "^Converged:" "${prefix}.log" | awk '{print $2}')
        core_ms=$(grep "^Core simulation time:" "${prefix}.log" | awk '{print $4}')
        parallelism=$(grep "^ForkJoinPool parallelism:" "${prefix}.log" | awk '{print $3}')

        echo "${cutoff},${rep},${timesteps},${converged},${core_ms},${parallelism}" >> "$CSV"
        echo "  [cutoff=$cutoff rep $rep/$REPS] core_ms=$core_ms parallelism=$parallelism"

        rm -f "${prefix}"_*.png
    done
done

echo
echo "Done. Raw data written to $CSV"