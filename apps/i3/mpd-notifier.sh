#!/bin/bash
#
# Event-driven MPD track notifier.
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/mpc

while true; do
    $BIN idleloop player | while read -r _; do
        STATE=$($BIN status %state%)

        if [ "$STATE" == "playing" ]; then
            TITLE=$($BIN current -f "%title%")
            ARTIST=$($BIN current -f "%artist%")
            [ -z "$TITLE" ] && TITLE=$($BIN current -f "%file%")
            
            dunstify -u low -r 9910 -i audio-speakers "Now Playing:" "<b>$TITLE</b>\n$ARTIST"
        elif [ "$STATE" == "paused" ]; then
            dunstify -u low -r 9910 -i audio-speakers "Playback Paused"
        elif [ "$STATE" == "stopped" ]; then
            dunstify -u low -r 9910 -i audio-speakers "Playback Stopped"
        fi
    done

    sleep 2
done
