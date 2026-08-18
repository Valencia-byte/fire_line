#!/usr/bin/env bash
#
# cutoff_sweep_v3.sh — cutoff sweep at a fixed configuration, now using a
# fixed timestep count rather than natural convergence, per the course's
# clarified benchmarking methodology: grid size should be the only thing
# affecting timing, and serial/parallel must do identical amounts of work.
# max-steps=1000 with a tight tolerance guarantees every run does exactly
# 1000 timesteps, no early convergence. Default (unmodified) ForkJoinPool
# parallelism throughout — only cutoff varies here.
#
# Runs are much cheaper under fixed timesteps than natural convergence was,
# so repetitions are bumped up substantially for better noise resistance.
#
# Usage: ./cutoff_sweep_v3.sh   (after `make all`)
# Output: output/profile/cutoff_sweep_v3.csv

set -u
BIN=bin
OUT=output/profile
mkdir -p "$OUT"

CSV="$OUT/cutoff_sweep_v3.csv"
echo "cutoff,repetition,timesteps,converged,core_ms,parallelism,load_avg_1min" > "$CSV"

REPS=15
ROWS=800
COLS=800
SEED=42
MODE=wildfire
LANDSCAPE=mixed
MAX_STEPS=1000
TOLERANCE=0.0001

for cutoff in 10 50 200 1000 5000 20000 80000 320000 700000; do
    for rep in $(seq 1 $REPS); do
        prefix="$OUT/cutoffv3_${cutoff}_rep${rep}"
        load=$(uptime | awk -F'load average: ' '{print $2}' | awk -F, '{print $1}')

        java -Dfireline.cutoff="$cutoff" \
             -cp "$BIN" FirelineParallel "$ROWS" "$COLS" "$SEED" "$MODE" "$prefix" \
             "$MAX_STEPS" "$TOLERANCE" "$LANDSCAPE" \
            > "${prefix}.log" 2>&1

        timesteps=$(grep "^Timesteps completed:" "${prefix}.log" | awk '{print $3}')
        converged=$(grep "^Converged:" "${prefix}.log" | awk '{print $2}')
        core_ms=$(grep "^Core simulation time:" "${prefix}.log" | awk '{print $4}')
        parallelism=$(grep "^ForkJoinPool parallelism:" "${prefix}.log" | awk '{print $3}')

        echo "${cutoff},${rep},${timesteps},${converged},${core_ms},${parallelism},${load}" >> "$CSV"
        echo "  [cutoff=$cutoff rep $rep/$REPS] core_ms=$core_ms timesteps=$timesteps converged=$converged"

        rm -f "${prefix}"_*.png
    done
done

echo
echo "Done. Raw data written to $CSV"