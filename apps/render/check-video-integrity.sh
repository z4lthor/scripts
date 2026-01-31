#!/bin/bash
#
# Check integrity of multiple video files
# Author: z4lthor <z4lthor@gmail.com>
#

set -euo pipefail

BIN=/usr/bin/ffmpeg
INPUTS=("$@")
VOB_IGNORE_WARNINGS=(
    "motion_type"
    "MVs not available"
    "invalid cbp"
    "ac-tex damaged"
    "slice mismatch"
    "incomplete frame"
    "frame size mismatch"
    "invalid packet size"
    "packet too small"
    "packet too large"
    "buffer underflow"
    "missing picture in sequence"
    "quantizer scale out of range"
    "concealing errors"
    "invalid vbv_delay"
    "Invalid frame dimensions"
    "Error submitting packet"
    "non monotonically increasing dts"
    "overread"
    "Last message repeated"
)

check_integrity() {
    local file="$1"

    result=$($BIN -v error -i "$file" -f null - 2>&1 || true)

    echo "$result"
}

is_vob() {
    local file="$1"

    [[ "${file,,}" == *.vob ]]
}

filter_vob_warnings() {
    local data="$1"
    local IGNORE_PATTERN=$(IFS='|'; echo "${VOB_IGNORE_WARNINGS[*]}")

    filtered=$(echo "$data" | grep -vE "$IGNORE_PATTERN" || true)

    echo "$filtered"
}

if ! command -v $BIN > /dev/null 2>&1; then
    echo "$BIN not found" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 INPUT..." >&2
    exit 1
fi

# Normalizing path names
for k in "${!INPUTS[@]}"; do
  INPUTS[$k]=$(realpath -m "${INPUTS[$k]}")
done

for input in "${INPUTS[@]}"; do
    if [[ ! -f "$input" ]]; then
        echo "Input file is invalid: $(basename "$input")"
        exit 1
    fi
done

echo "Checking integrity of ${#INPUTS[@]} file(s)..."

for k in "${!INPUTS[@]}"; do
    input="${INPUTS[$k]}"
    echo -n "$((k + 1))/${#INPUTS[@]} Checking $(basename "$input") video integrity ... "
    result=$(check_integrity "$input")

    if is_vob "$input"; then
        filtered=$(filter_vob_warnings "$result")
    else
        filtered="$result"
    fi

    if [[ -n "$filtered" ]]; then
        echo " Wrong"
        exit 1
    fi

    if is_vob "$input"; then
        echo "OK (VOB warnings filtered)"
    else
        echo "OK"
    fi
done

[[ $? -eq 0 ]] && exit 0 || exit 1
