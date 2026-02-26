#!/bin/bash
#
# Generates a list of installed packages sorted by disk usage (descending)
# Author: z4lthor <z4lthor@gmail.com>
#

if [[ $# -eq 0 ]]; then
    echo "Usage $0 <OUTPUT>"
    exit 1
fi

OUTPUT="$1"

pacman -Qie | grep -E '^(Name|Installed Size)' | cut -d: -f2 | paste -d' ' - - | awk '{
    if($3=="MiB") {val=$2*1024} 
    else if($3=="GiB") {val=$2*1024*1024} 
    else {val=$2}
    printf "%10d KB \t %s\n", val, $1
}' | sort -rn > "$OUTPUT"

exit 0
