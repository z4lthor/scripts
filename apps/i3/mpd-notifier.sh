#!/bin/bash
#
# Event-driven MPD track notifier.
# Author: z4lthor <z4lthor@gmail.com>
#

mpc idleloop player | while read -r _; do
    STATE=$(mpc status %state%)
    echo "$STATE"

    if [ "$STATE" == "playing" ]; then
        TITLE=$(mpc current -f "%title%")
        ARTIST=$(mpc current -f "%artist%")

        [ -z "$TITLE" ] && TITLE=$(mpc current -f "%file%")

        dunstify -u low -r 9910 -i audio-speakers "Now Playing:" "<b>$TITLE</b>\n$ARTIST"

    elif [ "$STATE" == "paused" ]; then
        dunstify -u low -r 9910 -i audio-speakers "Playback Paused"
    elif [ "$STATE" == "stopped" ]; then
        dunstify -u low -r 9910 -i audio-speakers "Playback Stopped"
    fi
done
