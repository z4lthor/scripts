#!/bin/bash
#
# Configure DPMS and screensaver settings for the current X session
# Author: z4lthor <z4lthor@gmail.com>
#

DEF_STANDBY=600
DEF_SUSPEND=800
DEF_OFF=1000
DEF_SCREENSAVER_DELAY_SEC=300

help() {
cat <<EOF
Usage: ${0##*/} [MODE]

Modes:
    normal                                  DPMS and screensaver are enabled. (By default)
                                            Delays: 
                                                standby=${DEF_STANDBY}s
                                                suspend=${DEF_SUSPEND}s
                                                off=${DEF_OFF}s
                                                screensaver=${DEF_SCREENSAVER_DELAY_SEC}s

    eco                                     DPMS enabled, screensaver disabled. 
                                            Delays times set to 50% of normal mode.

    always-on                               DPMS and screensaver are disabled.

    presentation                            Alias for always-on mode.

    lock                                    Lock screen immediately

    custom STANDBY SUSPEND OFF SCREENSAVER  Custom delays for DPMS and screensaver.
EOF
}

if [[ $# -gt 1 && $# -lt 5 ]] || [[ $# -gt 5 ]]; then
    help
    exit 1
fi

MODE=${1:-normal}
STANDBY=${2:-$DEF_STANDBY}
SUSPEND=${3:-$DEF_SUSPEND}
OFF=${4:-$DEF_OFF}
SCREENSAVER_DELAY_SEC=${5:-$DEF_SCREENSAVER_DELAY_SEC}

if [[ "$MODE" = "custom" && $# -ne 5 ]]; then
    help
    exit 1
fi

case "$MODE" in
    normal|custom)
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
    lock)
        xset s activate
        ;;
    *)
        help
        exit 1
        ;;
esac

echo "Set mode to $MODE"
