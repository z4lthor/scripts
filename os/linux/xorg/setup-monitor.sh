#!/bin/bash
#
# Configure DPMS and screensaver settings for the current X session
# Author: z4lthor <z4lthor@gmail.com>
#

STANDBY=600
SUSPEND=800
OFF=1000
SCREENSAVER_DELAY_SEC=300

STANDBY_ECO=$((STANDBY / 2))
SUSPEND_ECO=$((SUSPEND / 2))
OFF_ECO=$((OFF / 2))
SCREENSAVER_ECO_DELAY_SEC=$((SCREENSAVER_DELAY_SEC / 2))

if [[ $# -gt 1 ]]; then
    echo "Usage: ${0##*/} [MODE]"
    exit 1
fi

MODE=${1-normal}

case "$MODE" in
    normal)
        xset dpms $STANDBY $SUSPEND $OFF
        xset s "$SCREENSAVER_DELAY_SEC"
        xset s noblank
        ;;
    eco)
        xset dpms $STANDBY_ECO $SUSPEND_ECO $OFF_ECO
        xset s "$SCREENSAVER_ECO_DELAY_SEC"
        xset s blank
        ;;
    always-on|presentation)
        xset -dpms
        xset s off
        ;;
    *)
        echo "Error: Invalid mode. Modes=[normal|eco|always-on|presentation]" >&2
        exit 1
        ;;
esac

echo "Set mode to $MODE"
