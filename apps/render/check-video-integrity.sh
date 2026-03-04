#!/bin/bash
#
# Check integrity of multiple video files
# Author: z4lthor <z4lthor@gmail.com>
#

set -euo pipefail

FFPROBE_BIN=/usr/bin/ffprobe
FFMPEG_BIN=/usr/bin/ffmpeg
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

normalize_path_names() {
    local -n inputs=$1

    [[ ${#inputs[@]} -eq 0 ]] && return 0

    for k in "${!inputs[@]}"; do
        if [[ -n "${inputs[$k]}" ]]; then
            inputs[$k]=$(realpath -m -- "${inputs[$k]}")
        fi
    done
}

check_file() {
    local file="$1"

    if ! [[ -f "$file" && -r "$file" && -s "$file" ]]; then
        echo "Error: Input file is invalid: $(basename "$file")" >&2
        return 1
    fi

    if ! $FFPROBE_BIN -v error "$file" >/dev/null 2>&1; then
        echo "Error: Cannot read format: $(basename "$file")" >&2
        return 1
    fi

    local duration=$($FFPROBE_BIN -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")

    if [[ -z "$duration" || "$duration" = "N/A" ]] || ! is_positive "$duration"; then
        echo "Error: Invalid duration: $(basename "$file")" >&2
        return 1
    fi

    local streams=$($FFPROBE_BIN -v quiet -select_streams v -show_entries stream=index -of csv=p=0 "$file" | wc -l)

    if [[ "$streams" -eq 0 ]]; then
        echo "Error: No video streams: $(basename "$file")" >&2
        return 1
    fi

    return 0
}

check_integrity() {
    local file="$1"

    result=$($FFMPEG_BIN -v error -i "$file" -f null - 2>&1 || true)

    echo "$result"
}

is_vob() {
    local file="$1"

    [[ "${file,,}" == *.vob ]]
}

is_number() {
    local num="$1"

    [[ -z "$num" || "$num" =~ ^-?[0-9]*\.?[0-9]+$ ]]
}

is_positive() {
    local num="$1"

    if ! is_number "$num"; then
        return 1
    fi

    echo "$num > 0" | bc 2>/dev/null | grep -q 1
}

filter_vob_warnings() {
    local data="$1"
    local IGNORE_PATTERN=$(IFS='|'; echo "${VOB_IGNORE_WARNINGS[*]}")

    filtered=$(echo "$data" | grep -vE "$IGNORE_PATTERN" || true)

    echo "$filtered"
}

if ! command -v $FFPROBE_BIN > /dev/null 2>&1; then
    echo "$FFPROBE_BIN not found" >&2
    exit 1
fi

if ! command -v $FFMPEG_BIN > /dev/null 2>&1; then
    echo "$FFMPEG_BIN not found" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "Usage: $(basename "$0") INPUT..." >&2
    exit 1
fi

normalize_path_names INPUTS

for input in "${INPUTS[@]}"; do
    ! check_file "$input" && exit 1
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

exit 0
