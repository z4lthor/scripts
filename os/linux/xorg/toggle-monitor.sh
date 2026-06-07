#!/bin/bash
#
# Toogle secondary monitor
# Author: z4lthor <z4lthor@gmail.com>
#

is_connected() {
    local output=$1
    xrandr --query | grep -q "^$output connected"
}

is_active() {
    local output=$1
    xrandr --query | grep "^$output" | grep -qE "[0-9]+x[0-9]+\+[0-9]+\+[0-9]+"
}

get_primary() {
    xrandr --query | awk '/ primary / { print $1 }'
}

if [[ $# -eq 0 ]]; then
    echo "Usage: $(basename "$0") OUTPUT [POSITION]"
    exit 1
fi

OUTPUT=$1
POSITION=$2

if ! is_connected "$OUTPUT"; then
    echo "Error: Output $OUTPUT not found or connected"
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

PRIMARY=$(get_primary)

if is_active "$OUTPUT"; then
    echo "Turning off monitor on $OUTPUT"
    xrandr --output "$OUTPUT" --off
else
    echo "Turning on monitor on $OUTPUT"
    xrandr --output "$OUTPUT" --auto $POSITION_OPT "$PRIMARY"
fi

exit 0
