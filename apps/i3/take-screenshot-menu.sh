#!/bin/bash
#
# A simple power management script for i3wm using rofi.
# Author: z4lthor <z4lthor@gmail.com>
#

ID=1001
DSTDIR=${XDG_PICTURES_DIR:-$HOME/Pictures/Screenshots}
OPTS="󰍹 Monitor\n󱣴 Window\n󰩬 Selection"
STYLE=("-hide-scrollbar" \
       "-theme-str" "window {width: 15%;} listview {lines: 3;}" \
       "-padding" "20")

get_active_monitors() {
    xrandr --listactivemonitors | awk 'NR>1 {print $4}'
}

if [[ ! -d "$DSTDIR" ]]; then
    echo "Error: Directory $DSTDIR not exists. Creating directory"
    mkdir -p "$DSTDIR"
fi

if [[ ! -w "$DSTDIR" ]]; then
    echo "Error: Directory $DSTDIR not writable. Exiting application"
    exit 1
fi

OUTPUT="$DSTDIR/screenshot_$(date +%Y-%m-%d_%H:%M:%S).png"

SELECTION=$(echo -e "$OPTS" | rofi -dmenu -i -p 'Screenshot:' "${STYLE[@]}")
[[ -z "$SELECTION" ]] && exit 0

case "$SELECTION" in
    *Monitor)
        MONITORS=$(get_active_monitors)
        COUNT=$(echo "$MONITORS" | wc -l)

        if [[ "$COUNT" -gt 1 ]]; then
            OPTIONS=$(echo -e "All\n$MONITORS")
        else
            OPTIONS="$MONITORS"
        fi

        SELECTED=$(echo -e "$OPTIONS" | rofi -dmenu -i -p 'Monitor:' "${STYLE[@]}")
        [[ -z "$SELECTED" ]] && exit 0

        if [[ "$SELECTED" == "All" ]]; then
            take-screenshot -y "$OUTPUT"
        else
            take-screenshot -y -m "$SELECTED" "$OUTPUT"
        fi
        ;;
    *Window)
        take-screenshot -y -w "$OUTPUT"
        ;;
    *Selection)
        take-screenshot -y -s "$OUTPUT"
        ;;
esac

if [[ -f "$OUTPUT" ]]; then
    dunstify -r $ID \
    -a "Scrot" \
    -i "$OUTPUT" \
    "Snapshot Taken" \
    "File: $(basename "$OUTPUT")\nLocation: $DSTDIR" \
    --action="open,Open Folder"
else
    dunstify -u critical "Error" "Failed to take screenshot"
fi

exit 0
