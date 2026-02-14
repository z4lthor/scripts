#!/bin/bash
#
# Calculate total duration of video inputs in microseconds.
# Author: z4lthor <z4lthor@gmail.com>
#

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 INPUT..." >&2
    exit 1
fi

INPUTS=("$@")
total=0
error_found=0

for input in "${INPUTS[@]}"; do
    if [[ -f "$input" ]]; then
        duration=$(LC_ALL=C ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input")

        if [[ $duration =~ ^[0-9.]+$ ]]; then
            us=$(awk -v d="$duration" 'BEGIN { printf "%.0f", d * 1000000 }')
            total=$((total + us))
        else
            echo "Error: Cannot get the duration of $input" >&2
            error_found=1
        fi
    else
        echo "Error: File not found: $input" >&2
        error_found=1
    fi
done

echo "$total"

if [[ $error_found -eq 1 ]]; then
    exit 2
fi

exit 0
