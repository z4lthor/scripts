#!/bin/bash
#
# Take a screenshot of the entire desktop and save it as PNG
# Author: z4lthor <z4lthor@gmail.com>
#

DEFDIR=$HOME/Pictures/Screenshots
DSTDIR=${1:-$DEFDIR}
ID=1001

echo "Destination directory: $DSTDIR"

if [[ ! -d "$DSTDIR" ]]; then
    echo "Directory $DSTDIR doesn't exists"
    exit 1
fi

FILE="$DSTDIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

scrot -d 1 "$FILE"

if [[ -f "$FILE" ]]; then
    dunstify -r $ID \
             -a "Scrot" \
             -i "$FILE" \
             "Screenshot Taken" \
             "File: $(basename "$FILE")" \
             --action="open,Open Folder"
else
    dunstify -u critical "Error" "Failed to take screenshot"
fi
