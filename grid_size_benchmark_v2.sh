#!/usr/bin/env bash
#
# grid_size_benchmark_v2.sh — refined speedup dataset: tighter sampling
# around the serial/parallel crossover point (100-400), two additional
# points filling out the upper plateau (2000, 2400), and now a uniform
# 7 repetitions across every size rather than fewer at the large end.
# Same fixed methodology throughout: wildfire, mixed, seed 42, 1000
# fixed timesteps, tolerance 0.0001, parallel cutoff=1000, default
# ForkJoinPool parallelism.
#
# Usage: ./grid_size_benchmark_v2.sh   (after `make all`)
# Output: output/profile/grid_size_benchmark.csv

set -u
BIN=bin
OUT=output/profile
mkdir -p "$OUT"

CSV="$OUT/grid_size_benchmark.csv"
echo "program,size,repetition,timesteps,converged,core_ms" > "$CSV"

SEED=42
MODE=wildfire
LANDSCAPE=mixed
MAX_STEPS=1000
TOLERANCE=0.0001
CUTOFF=1000
REPS=7
SIZES="100 150 200 250 300 350 400 800 1600 2000 2400 3200"

run_serial() {
    local size="$1"
    for rep in $(seq 1 "$REPS"); do
        local prefix="$OUT/gridbench_serial_${size}_rep${rep}"
        java -cp "$BIN" FirelineSerial "$size" "$size" "$SEED" "$MODE" "$prefix" \
             "$MAX_STEPS" "$TOLERANCE" "$LANDSCAPE" \
            > "${prefix}.log" 2>&1

        local timesteps converged core_ms
        timesteps=$(grep "^Timesteps completed:" "${prefix}.log" | awk '{print $3}')
        converged=$(grep "^Converged:" "${prefix}.log" | awk '{print $2}')
        core_ms=$(grep "^Core simulation time:" "${prefix}.log" | awk '{print $4}')

        echo "serial,${size},${rep},${timesteps},${converged},${core_ms}" >> "$CSV"
        echo "  [serial ${size}x${size} rep $rep/$REPS] core_ms=$core_ms"
        rm -f "${prefix}"_*.png
    done
}

run_parallel() {
    local size="$1"
    for rep in $(seq 1 "$REPS"); do
        local prefix="$OUT/gridbench_parallel_${size}_rep${rep}"
        java -Dfireline.cutoff="$CUTOFF" \
             -cp "$BIN" FirelineParallel "$size" "$size" "$SEED" "$MODE" "$prefix" \
             "$MAX_STEPS" "$TOLERANCE" "$LANDSCAPE" \
            > "${prefix}.log" 2>&1

        local timesteps converged core_ms
        timesteps=$(grep "^Timesteps completed:" "${prefix}.log" | awk '{print $3}')
        converged=$(grep "^Converged:" "${prefix}.log" | awk '{print $2}')
        core_ms=$(grep "^Core simulation time:" "${prefix}.log" | awk '{print $4}')

        echo "parallel,${size},${rep},${timesteps},${converged},${core_ms}" >> "$CSV"
        echo "  [parallel ${size}x${size} rep $rep/$REPS] core_ms=$core_ms"
        rm -f "${prefix}"_*.png
    done
}

echo "== Refined grid-size benchmark: wildfire, mixed, seed 42, 1000 fixed timesteps, 7 reps =="
echo

for size in $SIZES; do
    run_serial "$size"
    run_parallel "$size"
done

echo
echo "Done. Raw data written to $CSV"