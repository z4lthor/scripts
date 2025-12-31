#!/bin/bash
#
# Check integrity of multiple video files
# Author: z4lthor <z4lthor@gmail.com>
#

set -euo pipefail

BIN=/usr/bin/ffmpeg
INPUTS=("$@")
ERRORS_FOUND=0
WARNINGS_FOUND=0
VOB_MODE=false
VOB_IGNORE_PATTERNS=(
    "incomplete frame"
    "non monotonically increasing dts"
    "overread"
    "ac-tex damaged"
    "Warning MVs not available"
    "Invalid frame dimensions 0x0"
    "Error submitting packet to decoder"
    "Invalid data found when processing input"
    "Last message repeated"
    "packet too small"
    "buffer underflow"
)

all_vobs() {
    local all=true

    for file in "${INPUTS[@]}"; do
        if ! is_vob "$file"; then
            all=false
            break
        fi
    done

    [[ "$all" == true ]]
}

is_vob() {
    local file="$1"

    [[ "${file,,}" == *.vob ]]
}

filter_vob_warnings() {
    local filtered="$1"

    for pattern in "${VOB_IGNORE_PATTERNS[@]}"; do
        filtered=$(echo "$filtered" | grep -v "$pattern" || true)
    done

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

if all_vobs && [[ ${#INPUTS[@]} -gt 0 ]]; then
    VOB_MODE=true
    echo "VOB mode enabled"
fi

echo "Checking integrity of ${#INPUTS[@]} file(s)..."

for file in "${INPUTS[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "File not valid: $file" >&2
        ERRORS_FOUND=$((ERRORS_FOUND + 1))
        continue
    fi

    filename=$(basename "$file")
    echo -n "Checking: $filename ..."
    
    err_output=$($BIN -v error -i "$file" -f null - 2>&1 || true)

    if $VOB_MODE; then
        filtered_errors=$(filter_vob_warnings "$err_output")
    else
        filtered_errors="$err_output"
    fi

    if [[ -z "$filtered_errors" ]]; then
        if [[ -n "$err_output" ]] && $VOB_MODE; then
            echo " OK (normal VOB warnings filtered)"
            WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
        else
            echo " OK"
        fi
    else
        echo " ERRORS FOUND"
        echo "$filtered_errors" | sed 's/^/      /'
        ERRORS_FOUND=$((ERRORS_FOUND + 1))
    fi
done

echo "  Total files: ${#INPUTS[@]}"

if $VOB_MODE; then
    echo "  Passed (with filtered warnings): $WARNINGS_FOUND"
    echo "  Perfect (no warnings): $((${#INPUTS[@]} - ERRORS_FOUND - WARNINGS_FOUND))"
else
    echo "  Passed: $((${#INPUTS[@]} - ERRORS_FOUND))"
fi

if [[ $ERRORS_FOUND -gt 0 ]]; then
    echo "  Failed: $ERRORS_FOUND" >&2
fi

echo ""

if [[ $ERRORS_FOUND -gt 0 ]]; then
    echo "Errors found. These files may be corrupted or unplayable."
    exit 1
elif [[ $WARNINGS_FOUND -gt 0 ]] && $VOB_MODE; then
    echo "VOB files have normal DVD structure warnings but should be playable."
    exit 0
else
    echo "All files passed integrity check."
    exit 0
fi
