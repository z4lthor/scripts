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

confirm() {
    echo -e "󰄬 Yes\n󰏐 No" | rofi -dmenu -i -p "Confirm $1?" \
        -theme-str 'window {width: 25%;} listview {lines: 2;}'
}

! check_command toggle-monitor && exit 1

[[ $(confirm "Toggle Monitor") == *"Yes" ]] && toggle-monitor "$OUTPUT"
