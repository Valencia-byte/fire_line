#!/usr/bin/env bash
#
# validate.sh — compares FirelineSerial and FirelineParallel output.
#
# Two kinds of check are run:
#   1. Configuration coverage: different grid shapes, modes, landscapes and
#      seeds, each compared once (parallel run with a small cutoff, so real
#      splitting actually happens).
#   2. Cutoff/parallelism robustness: one fixed scenario, run serially once
#      and compared against many different cutoff/parallelism combinations,
#      to show correctness does not depend on how the region gets divided.
#
# A run is a PASS only if every printed simulation-result field matches
# AND all three output PNGs are byte-identical.
#
# Usage: ./validate.sh   (run from the project root, after `make all`)

set -u

BIN=bin
OUT=output/validate
mkdir -p "$OUT"

PASS=0
FAIL=0

# Prints only the simulation-result lines that must match between a serial
# and a parallel run. Deliberately excludes: the banner line ("Fireline
# serial/parallel simulation"), the timing line, the output-path line, and
# the parallel-only cutoff/parallelism diagnostic lines -- all of those are
# expected to differ and are not correctness signals.
extract_result() {
    grep -E "^(Mode|Rows|Random seed|Landscape|Initial source|Timesteps completed|Converged|Final burning cells|Cells burned|Maximum peak temperature|Maximum change)" "$1"
}

compare_outputs() {
    local label="$1" serial_log="$2" parallel_log="$3" serial_prefix="$4" parallel_prefix="$5"

    local serial_fields parallel_fields
    serial_fields=$(extract_result "$serial_log")
    parallel_fields=$(extract_result "$parallel_log")

    local stats_ok=1 images_ok=1
    if [ "$serial_fields" != "$parallel_fields" ]; then
        stats_ok=0
    fi

    for suffix in terrain peak final; do
        if ! cmp -s "${serial_prefix}_${suffix}.png" "${parallel_prefix}_${suffix}.png"; then
            images_ok=0
        fi
    done

    if [ "$stats_ok" -eq 1 ] && [ "$images_ok" -eq 1 ]; then
        echo "PASS  $label"
        PASS=$((PASS + 1))
    else
        echo "FAIL  $label (stats_ok=$stats_ok images_ok=$images_ok)"
        FAIL=$((FAIL + 1))
        if [ "$stats_ok" -eq 0 ]; then
            echo "  --- serial ---"
            echo "$serial_fields" | sed 's/^/  /'
            echo "  --- parallel ---"
            echo "$parallel_fields" | sed 's/^/  /'
        fi
    fi
}

echo "== Part 1: configuration coverage (cutoff=50, parallelism=8) =="
echo

run_case() {
    local name="$1" rows="$2" cols="$3" seed="$4" mode="$5" landscape="$6"
    local sprefix="$OUT/${name}_serial"
    local pprefix="$OUT/${name}_parallel"

    java -cp "$BIN" FirelineSerial "$rows" "$cols" "$seed" "$mode" "$sprefix" 5000 0.05 "$landscape" \
        > "${sprefix}.log" 2>&1
    java -Dfireline.cutoff=50 \
         -Djava.util.concurrent.ForkJoinPool.common.parallelism=8 \
         -cp "$BIN" FirelineParallel "$rows" "$cols" "$seed" "$mode" "$pprefix" 5000 0.05 "$landscape" \
        > "${pprefix}.log" 2>&1

    compare_outputs "$name" "${sprefix}.log" "${pprefix}.log" "$sprefix" "$pprefix"
}

run_case square_wildfire_mixed   300 300 42  wildfire  mixed
run_case square_diffusion_mixed  300 300 42  diffusion mixed
run_case square_wildfire_grass   300 300 42  wildfire  grass
run_case wide_wildfire_mixed     150 450 7   wildfire  mixed
run_case tall_wildfire_mixed     450 150 7   wildfire  mixed
# grass, not mixed: the mixed-landscape generator can fail to route a river
# around rocks at this grid size, for reasons unrelated to parallelisation.
run_case minimum_size_wildfire   20  20  1   wildfire  grass
run_case alternate_seed_wildfire 300 300 999 wildfire  mixed

echo
echo "== Part 2: cutoff/parallelism robustness (fixed 300x300 wildfire mixed seed=42) =="
echo

FIXED_SERIAL_PREFIX="$OUT/fixed_serial"
java -cp "$BIN" FirelineSerial 300 300 42 wildfire "$FIXED_SERIAL_PREFIX" 5000 0.05 mixed \
    > "${FIXED_SERIAL_PREFIX}.log" 2>&1

for cutoff in 10 500 5000 500000; do
    for parallelism in 1 4 8; do
        pprefix="$OUT/fixed_c${cutoff}_p${parallelism}"
        java -Dfireline.cutoff="$cutoff" \
             -Djava.util.concurrent.ForkJoinPool.common.parallelism="$parallelism" \
             -cp "$BIN" FirelineParallel 300 300 42 wildfire "$pprefix" 5000 0.05 mixed \
            > "${pprefix}.log" 2>&1
        compare_outputs "cutoff=$cutoff parallelism=$parallelism" \
            "${FIXED_SERIAL_PREFIX}.log" "${pprefix}.log" "$FIXED_SERIAL_PREFIX" "$pprefix"
    done
done

echo
echo "== Summary: $PASS passed, $FAIL failed =="
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi