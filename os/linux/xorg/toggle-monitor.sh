#!/bin/bash
#
# Toogle a secondary monitor on and off
# Author: z4lthor <z4lthor@gmail.com>
#

is_connected() {
    local input=$1
    xrandr --query | grep "connected" | grep -q "^$input"
}

is_active() {
    local input=$1
    xrandr --query | grep "^$input" | grep -qE "[0-9]+x[0-9]+\+[0-9]+\+[0-9]+"
}

if [[ $# -eq 0 ]]; then
    echo "Usage: $(basename "$0") INPUT [POSITION]"
    exit 1
fi

INPUT=$1
POSITION=$2

# if ! xrandr --query | grep "connected" | grep -q "^$INPUT"; then
if ! is_connected $INPUT; then
    echo "Error: Input $INPUT not found or connected"
    exit 1
fi

if [[ -z "$POSITION" ]]; then
    POSITION="right"
fi

case "$POSITION" in
  left)
    POSITION_OPT="--left-of"
    ;;
  right)
    POSITION_OPT="--right-of"
    ;;
  above)
    POSITION_OPT="--above"
    ;;
  below)
    POSITION_OPT="--below"
    ;;
  same-as)
    POSITION_OPT="--same-as"
    ;;
  *)
    echo "Invalid position: $POSITION"
    echo "Available positions: left, right, above, below, same-as"
    exit 1
    ;;
esac

PRIMARY=$(xrandr --query | awk '/ primary / { print $1 }')

if is_active $INPUT; then
    echo "Turning off monitor on $INPUT"
    xrandr --output $INPUT --off
else
    echo "Turning on monitor on $INPUT"
    xrandr --output $INPUT --auto $POSITION_OPT $PRIMARY
fi

exit 0
