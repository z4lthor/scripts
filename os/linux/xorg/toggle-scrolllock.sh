#!/bin/bash
#
# Toggle Scroll Lock to turn the keyboard backlight on/off
# Author: z4lthor <z4lthor@gmail.com>
#

turnon() {
    xset led 3
}

turnoff() {
    xset -led 3
}

ACTION="$1"

if [[ -n "$ACTION" ]]; then
    case "$ACTION" in
        "on") turnon ;;
        "off") turnoff ;;
        *) echo "Usage: $0 [on|off]" && exit 1 ;;
    esac

    exit 0
fi

MASK=$(xset q | grep "LED mask" | awk '{print $10}')

if (( 0x$MASK & 4 )); then
    turnoff
else
    turnon
fi

exit 0
