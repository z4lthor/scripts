#!/bin/bash
#
# Check integrity of multiple video files
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/ffmpeg
INPUTS=("$@")

for input in "${INPUTS[@]}"; do
    if [[ ! -f "$input" ]]; then
        echo "Input file is invalid $input"
        exit 1
    fi
done

for file in "${INPUTS[@]}"; do
    echo "Checking: $(basename "$file")"
    ffmpeg -v error -i "$file" -f null -

    if [[ $? -eq 0 ]]; then
        echo "File $(basename "$file") integrity: OK"
    else
        echo "File $(basename "$file") integrity: Error"
    fi
done

exit 0
