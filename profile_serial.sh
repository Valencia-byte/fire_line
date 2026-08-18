#!/usr/bin/env bash
#
# profile_serial.sh — profiles FirelineSerial across grid sizes, modes and
# landscapes, with repeated runs per configuration.
#
# Sizes and repetition counts below were chosen from pilot timing data
# (100-1600, wildfire+mixed): time grows roughly 8x per doubling of grid
# dimension, not 4x, because timesteps-to-convergence also grows with grid
# size. 1600x1600 alone costs ~8 minutes per run, so full repetitions are
# only used up to 800x800; 1600 and 2000 are single/light "anchor" points
# to show the trend continues without an impractical total runtime.
#
# Usage: ./profile_serial.sh   (run from the project root, after `make all`)
# Output: output/profile/serial_profile.csv

set -u
BIN=bin
OUT=output/profile
mkdir -p "$OUT"

CSV="$OUT/serial_profile.csv"
echo "label,rows,columns,mode,landscape,seed,repetition,timesteps,converged,cells_burned,core_ms" > "$CSV"

run_and_record() {
    local label="$1" rows="$2" cols="$3" seed="$4" mode="$5" landscape="$6" reps="$7"

    for rep in $(seq 1 "$reps"); do
        local prefix="$OUT/${label}_rep${rep}"
        java -cp "$BIN" FirelineSerial "$rows" "$cols" "$seed" "$mode" "$prefix" 50000 0.05 "$landscape" \
            > "${prefix}.log" 2>&1

        local timesteps converged cells_burned core_ms
        timesteps=$(grep "^Timesteps completed:" "${prefix}.log" | awk '{print $3}')
        converged=$(grep "^Converged:" "${prefix}.log" | awk '{print $2}')
        cells_burned=$(grep "^Cells burned:" "${prefix}.log" | awk '{print $3}')
        core_ms=$(grep "^Core simulation time:" "${prefix}.log" | awk '{print $4}')

        echo "${label},${rows},${cols},${mode},${landscape},${seed},${rep},${timesteps},${converged},${cells_burned},${core_ms}" >> "$CSV"
        echo "  [$label rep $rep/$reps] timesteps=$timesteps core_ms=$core_ms"

        # Keep images from only the first repetition per config, to save disk space.
        if [ "$rep" -gt 1 ]; then
            rm -f "${prefix}"_*.png
        fi
    done
}

echo "== Core sweep: sizes 100-800, 5 reps, all mode x landscape combinations =="
for mode in wildfire diffusion; do
    for landscape in mixed grass; do
        for size in 100 200 400 800; do
            run_and_record "sq${size}_${mode}_${landscape}" "$size" "$size" 42 "$mode" "$landscape" 5
        done
    done
done

echo
echo "== Large-size anchor points: wildfire+mixed only, fewer reps =="
run_and_record "sq1600_wildfire_mixed" 1600 1600 42 wildfire mixed 2
run_and_record "sq2000_wildfire_mixed" 2000 2000 42 wildfire mixed 1

echo
echo "Done. Raw data written to $CSV"