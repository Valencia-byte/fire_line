#!/usr/bin/env bash
#
# parallelism_sweep.sh — investigates the effect of ForkJoinPool parallelism
# at the now-fixed cutoff (1000), same fixed-timestep configuration used
# throughout: 800x800 wildfire, mixed, seed 42, 1000 timesteps, tight
# tolerance. Only parallelism level varies between runs.
#
# Usage: ./parallelism_sweep.sh   (after `make all`)
# Output: output/profile/parallelism_sweep.csv

set -u
BIN=bin
OUT=output/profile
mkdir -p "$OUT"

CSV="$OUT/parallelism_sweep.csv"
echo "parallelism_requested,repetition,timesteps,converged,core_ms,parallelism_actual,load_avg_1min" > "$CSV"

REPS=10
ROWS=800
COLS=800
SEED=42
MODE=wildfire
LANDSCAPE=mixed
MAX_STEPS=1000
TOLERANCE=0.0001
CUTOFF=1000

for parallelism in 1 2 3 4 5 6 7 8; do
    for rep in $(seq 1 $REPS); do
        prefix="$OUT/parallelism_${parallelism}_rep${rep}"
        load=$(uptime | awk -F'load average: ' '{print $2}' | awk -F, '{print $1}')

        java -Dfireline.cutoff="$CUTOFF" \
             -Djava.util.concurrent.ForkJoinPool.common.parallelism="$parallelism" \
             -cp "$BIN" FirelineParallel "$ROWS" "$COLS" "$SEED" "$MODE" "$prefix" \
             "$MAX_STEPS" "$TOLERANCE" "$LANDSCAPE" \
            > "${prefix}.log" 2>&1

        timesteps=$(grep "^Timesteps completed:" "${prefix}.log" | awk '{print $3}')
        converged=$(grep "^Converged:" "${prefix}.log" | awk '{print $2}')
        core_ms=$(grep "^Core simulation time:" "${prefix}.log" | awk '{print $4}')
        parallelism_actual=$(grep "^ForkJoinPool parallelism:" "${prefix}.log" | awk '{print $3}')

        echo "${parallelism},${rep},${timesteps},${converged},${core_ms},${parallelism_actual},${load}" >> "$CSV"
        echo "  [parallelism=$parallelism rep $rep/$REPS] core_ms=$core_ms parallelism_actual=$parallelism_actual"

        rm -f "${prefix}"_*.png
    done
done

echo
echo "Done. Raw data written to $CSV"