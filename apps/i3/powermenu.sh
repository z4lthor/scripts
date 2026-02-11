#!/bin/bash
#
# A simple power management script for i3wm using rofi.
# Author: z4lthor <z4lthor@gmail.com>
#

OPTS="󰐥 Poweroff\n󰜉 Restart\n󰤄 Suspend\n󰗽 Close Session"

confirm() {
    echo -e "󰄬 Yes\n󰏐 No" | rofi -dmenu -i -p "Confirm $1?" \
        -theme-str 'window {width: 12%;} listview {lines: 2;}'
}

SELECTION=$(echo -e "$OPTS" | rofi -dmenu -i -p "System:" \
    -hide-scrollbar \
    -theme-str 'window {width: 15%;} listview {lines: 4;}' \
    -padding 20)

case "$SELECTION" in
    *Poweroff)
        [[ $(confirm "Poweroff") == "*Yes" ]] && systemctl poweroff ;;
    *Restart)
        [[ $(confirm "Restart") == "*Yes" ]] && systemctl reboot ;;
    *Suspend)
        systemctl suspend ;;
    *Close*)
        [[ $(confirm "Close") == "*Yes" ]] && i3-msg exit ;;
esac
