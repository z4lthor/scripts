#!/bin/bash
#
# Configure DPMS and screensaver settings for the current X session
# Author: z4lthor <z4lthor@gmail.com>
#

STANDBY=600
SUSPEND=800
OFF=1000
SCREENSAVER_DELAY_SEC=300

help() {
cat <<EOF
Usage: ${0##*/} [MODE]

Modes:
    normal          DPMS and screensaver are enabled. (By default)
                    Delays: screensaver=300s, standby=600s, suspend=800s, off=1000s

    eco             DPMS enabled, screensaver disabled. 
                    Delays times set to 50% of normal mode.

    always-on       DPMS and screensaver are disabled.

    presentation    Alias for always-on mode.
EOF
}

if [[ $# -gt 1 ]]; then
    help
    exit 1
fi

MODE=${1:-normal}

case "$MODE" in
    normal)
        xset +dpms
        xset dpms $STANDBY $SUSPEND $OFF
        xset s "$SCREENSAVER_DELAY_SEC"
        xset s noblank
        ;;
    eco)
        xset +dpms
        xset dpms $((STANDBY / 2)) $((SUSPEND / 2)) $((OFF / 2))
        xset s off
        ;;
    always-on|presentation)
        xset -dpms
        xset s off
        ;;
    *)
        help
        exit 1
        ;;
esac

echo "Set mode to $MODE"
