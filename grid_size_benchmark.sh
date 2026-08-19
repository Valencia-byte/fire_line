#!/usr/bin/env bash
#
# grid_size_benchmark.sh — the main speedup dataset. Runs both
# FirelineSerial and FirelineParallel across a range of grid sizes, all
# under the fixed methodology settled on so far: wildfire mode, mixed
# landscape, seed 42, fixed 1000 timesteps (tight tolerance so nothing
# converges early), parallel using the settled cutoff=1000 and the JVM's
# default (unmodified) ForkJoinPool parallelism.
#
# Repetitions are graduated: more reps for cheap small sizes, fewer for
# the largest, to keep total runtime reasonable without sacrificing
# statistical power where it's cheap to have it.
#
# Usage: ./grid_size_benchmark.sh   (after `make all`)
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

run_serial() {
    local size="$1" reps="$2"
    for rep in $(seq 1 "$reps"); do
        local prefix="$OUT/gridbench_serial_${size}_rep${rep}"
        java -cp "$BIN" FirelineSerial "$size" "$size" "$SEED" "$MODE" "$prefix" \
             "$MAX_STEPS" "$TOLERANCE" "$LANDSCAPE" \
            > "${prefix}.log" 2>&1

        local timesteps converged core_ms
        timesteps=$(grep "^Timesteps completed:" "${prefix}.log" | awk '{print $3}')
        converged=$(grep "^Converged:" "${prefix}.log" | awk '{print $2}')
        core_ms=$(grep "^Core simulation time:" "${prefix}.log" | awk '{print $4}')

        echo "serial,${size},${rep},${timesteps},${converged},${core_ms}" >> "$CSV"
        echo "  [serial ${size}x${size} rep $rep/$reps] core_ms=$core_ms"
        rm -f "${prefix}"_*.png
    done
}

run_parallel() {
    local size="$1" reps="$2"
    for rep in $(seq 1 "$reps"); do
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
        echo "  [parallel ${size}x${size} rep $rep/$reps] core_ms=$core_ms"
        rm -f "${prefix}"_*.png
    done
}

echo "== Grid-size benchmark: wildfire, mixed, seed 42, 1000 fixed timesteps =="
echo

for size in 100 200 400 800; do
    run_serial "$size" 7
    run_parallel "$size" 7
done

for size in 1600 3200; do
    run_serial "$size" 3
    run_parallel "$size" 3
done

echo
echo "Done. Raw data written to $CSV"