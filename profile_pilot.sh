#!/usr/bin/env bash
#
# profile_pilot.sh — quick timing sanity check across a few grid sizes,
# one repetition each. Run this first to calibrate the real profiling
# sweep's size range and repetition count.
#
# Usage: ./profile_pilot.sh   (run from the project root, after `make all`)

set -u
BIN=bin
OUT=output/profile
mkdir -p "$OUT"

for size in 100 200 400 800 1600; do
    prefix="$OUT/pilot_sq${size}"
    START=$(date +%s)
    java -cp "$BIN" FirelineSerial "$size" "$size" 42 wildfire "$prefix" 50000 0.05 mixed \
        > "${prefix}.log" 2>&1
    END=$(date +%s)

    timesteps=$(grep "^Timesteps completed:" "${prefix}.log" | awk '{print $3}')
    converged=$(grep "^Converged:" "${prefix}.log" | awk '{print $2}')
    core_ms=$(grep "^Core simulation time:" "${prefix}.log" | awk '{print $4}')

    echo "${size}x${size}: wall_clock=$((END - START))s  core_ms=${core_ms}  timesteps=${timesteps}  converged=${converged}"
done