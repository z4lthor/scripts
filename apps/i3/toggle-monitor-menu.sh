#!/bin/bash
#
# Toggle monitor script for i3wm using rofi.
# Author: z4lthor <z4lthor@gmail.com>
#

OUTPUT="HDMI-0"

check_command() {
    local bin="$1"

    command -v "$bin" > /dev/null 2>&1
}

is_connected() {
    local output=$1
    xrandr --query | grep -q "^$output connected"
}

confirm() {
    echo -e "󰄬 Yes\n󰏐 No" | rofi -dmenu -i -p "Confirm $1?" \
        -theme-str 'window {width: 25%;} listview {lines: 2;}'
}

! check_command toggle-monitor && exit 1

if ! is_connected "$OUTPUT"; then
    dunstify -u critical -t 2000 "Output $OUTPUT is disconnected"
    exit 1
fi

[[ $(confirm "Toggle Monitor") == *"Yes" ]] && toggle-monitor "$OUTPUT"
