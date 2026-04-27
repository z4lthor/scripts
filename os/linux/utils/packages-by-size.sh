#!/bin/bash
#
# Generates a list of installed packages sorted by disk usage (descending)
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/pacman

if ! command -v "$BIN" > /dev/null 2>&1; then
    echo "$BIN not found"
    exit 1
fi

if [[ $# -gt 1 ]]; then
    echo "Usage $(basename "$0") [OUTPUT]"
    exit 1
fi

OUTPUT=${1:-./$(hostname)_packages_$(date +%Y-%m-%d_%H-%M-%S).txt}
DSTDIR=$(dirname "$OUTPUT")

if [[ ! -d "$DSTDIR" ]]; then
    echo "Error: Directory $DSTDIR not exists"
    exit 1
fi

if [[ ! -w "$DSTDIR" ]]; then
    echo "Error: Directory $DSTDIR not writable"
    exit 1
fi

"$BIN" -Qie | grep -E '^(Name|Installed Size)' | cut -d: -f2 | paste -d' ' - - | awk '{
    if($3=="MiB") {val=$2*1024} 
    else if($3=="GiB") {val=$2*1024*1024} 
    else {val=$2}
    printf "%10d KB \t %s\n", val, $1
}' | sort -rn > "$OUTPUT"

exit 0
