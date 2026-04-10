#!/bin/bash
#
# A script to manage i3lock with custom config and wallpaper support
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/i3lock
OPTS=(--nofork -e -f -t)
CONFIG="$HOME/.config/i3/i3lock.conf"

check_command() {
    local bin="$1"

    command -v "$bin" > /dev/null 2>&1
}

if ! check_command $BIN; then
    echo "Error: $BIN not found" >&2
    exit 1
fi

if [[ -z "$DISPLAY" ]] || ! xset q >/dev/null 2>&1; then
    echo "Error: X server is down or not available" >&2
    exit 1
fi

if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
else
    echo "WALLPAPER=\"/path/to/imagen.png\"" > "$CONFIG"
    echo "Error: Config created at $CONFIG. Please edit it." >&2
    exit 1
fi

if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    echo "Error: Wallpaper not found or not defined: $WALLPAPER" >&2
    exit 1
fi

$BIN "${OPTS[@]}" -i "$WALLPAPER"

exit 0
