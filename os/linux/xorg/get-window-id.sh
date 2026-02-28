#!/bin/bash
#
# Simple H.265/HEVC encoding script based on ffmpeg.
# Get window selected ID on Xorg
# Author: z4lthor <z4lthor@gmail.com>
#

if [[ -z "$DISPLAY" ]] || ! xset q >/dev/null 2>&1; then
    echo "Error: X server is down or not available"
    exit 1
fi

if ! XWININFO_OUTPUT=$(xwininfo 2>&1); then
    echo "Error: xwininfo process failed" >&2
    exit 1
fi

ID=$(awk '/Window id:/ {print substr($4, 3)}' <<< "$XWININFO_OUTPUT")

if [[ -z "$ID" ]]; then
    echo "Error: Selection void or cancelled" >&2
    exit 1
fi

echo "$ID"

