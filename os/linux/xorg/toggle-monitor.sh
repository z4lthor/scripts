#!/bin/bash
#
# Toogle a secondary monitor on and off
# Author: z4lthor <z4lthor@gmail.com>
#

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 INPUT"
    exit 1
fi

INPUT=$1

if ! xrandr --query | grep "connected" | grep -q "^$INPUT"; then
    echo "Error: Input $INPUT not found or connected"
    exit 1
fi

PRIMARY=$(xrandr --query | awk '/ primary / { print $1 }')

if xrandr --query | grep "^$INPUT" | grep -qE "[0-9]+x[0-9]+\+[0-9]+\+[0-9]+"; then
    echo "Turning off monitor on $INPUT"
    xrandr --output $INPUT --off
else
    echo "Turning on monitor on $INPUT"
    xrandr --output $INPUT --auto --right-of $PRIMARY
fi

exit 0
