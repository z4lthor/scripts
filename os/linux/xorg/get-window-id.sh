#!/bin/bash
#
# Get window selected ID on Xorg
# Author: z4lthor <z4lthor@gmail.com>
#

set -euo pipefail

if [[ -z "$DISPLAY" ]] || ! xset q >/dev/null 2>&1; then
    echo "Error: X server is down or not available" >&2
    exit 1
fi

if ! XWININFO_OUTPUT=$(xwininfo 2>&1); then
    echo "Error: xwininfo process failed" >&2
    exit 1
fi

ID=$(awk '/Window id:/ {print $4}' <<< "$XWININFO_OUTPUT")

if [[ -z "$ID" ]]; then
    echo "Error: Could not extract window ID from xwininfo" >&2
    exit 1
fi

echo "$ID"
