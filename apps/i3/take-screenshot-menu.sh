#!/bin/bash
#
# A simple power management script for i3wm using rofi.
# Author: z4lthor <z4lthor@gmail.com>
#

DEST_DIR=$HOME/Pictures/Screenshots
ID=1001

if FILE=$(take-screenshot -d "$DEST_DIR"); then
    dunstify -r $ID \
             -a "Scrot" \
             -i "$FILE" \
             "Snapshot Taken" \
             "File: $(basename "$FILE")\nLocation: $DEST_DIR" \
             --action="open,Open Folder"
else
    dunstify -u critical "Error" "Failed to take screenshot"
fi
