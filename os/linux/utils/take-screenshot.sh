#!/bin/bash
#
# Take a screenshot of the entire desktop and save it as PNG
# Author: z4lthor <z4lthor@gmail.com>
#

DEFDIR=$HOME/Pictures/Screenshots
DSTDIR=${1:-$DEFDIR}

if [[ ! -d "$DSTDIR" ]]; then
    echo "Directory $DSTDIR does not exists. Creating it..."
    if ! mkdir -p "$DSTDIR"; then
        echo "Error: Failed to create directory $DSTDIR" >&2
        exit 1
    fi
fi

if [[ ! -w "$DSTDIR" ]]; then
    echo "Error: Directory $DSTDIR is not writable" >&2
    exit 1
fi

FILE="$DSTDIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

if scrot -d 1 "$FILE"; then
    echo "Screenshot $(basename "$FILE") saved in $(dirname "$FILE")"
    exit 0
else
    echo "Error: scrot failed" >&2
    exit 1
fi
