#!/bin/bash
#
# MPD status icon provider for Polybar modules.
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/mpc
STATE=$($BIN status %state% 2>/dev/null)

if [ "$STATE" == "playing" ]; then
    echo "󰐊"
elif [ "$STATE" == "paused" ]; then
    echo "󰏤"
else
    echo "󰓛"
fi
