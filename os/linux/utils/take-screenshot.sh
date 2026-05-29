#!/bin/bash
#
# Take a screenshot of the entire desktop and save it as PNG
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/scrot
POSITION_OPTS=()
WINDOW=false
FOCUS=false
SELECT=false
TIME=1

help() {
cat <<EOF
Usage:
$(basename "$0") [OPTION]... [OUTPUT]

Options:
-m, --monitor MONITOR       Screenshot to MONITOR
-w, --window                Screenshot to window
-f, --focus                 Screenshot to focused window
-s, --select                Screenshot to selection
-t, --time SECONDS          Seconds to wait
-y, --yes                   Skip all prompts
-h, --help                  Show this help
EOF
}

check_command() {
    local bin="$1"

    command -v "$bin" > /dev/null 2>&1
}

confirm_action() {
    [[ -n "$SKIP_PROMPTS" && "$SKIP_PROMPTS" = "true" ]] && return 0;

    while true; do
        read -r -p "$1 [y/n]: " RESP
        case "$RESP" in
            y|Y)
                return 0
                ;;
            n|N)
                return 1
                ;;
            *)
                error "Invalid response. Try again."
                ;;
        esac
    done
}

get_monitor_geometry() {
    local monitor="$1"

    xrandr --query | grep "^$monitor" | grep -oP '\d+x\d+\+\d+\+\d+' | tr 'x+' ' '
}

get_window_geometry() {
    local cmd="$1"

    xdotool "$cmd" getwindowgeometry --shell | \
    sed -n 's/^X=\([0-9]*\).*/\1/p;s/^Y=\([0-9]*\).*/\1/p;s/^WIDTH=\([0-9]*\).*/\1/p;s/^HEIGHT=\([0-9]*\).*/\1/p' | xargs
}

get_selected_window_geometry() {
    get_window_geometry "selectwindow"
}

get_focused_window_geometry() {
    get_window_geometry "getwindowfocus"
}

is_number() {
    local num=$1

    [[ "$num" =~ ^[0-9]+$ ]]
}

if [[ -z "$DISPLAY" ]] || ! xset q >/dev/null 2>&1; then
    echo "Error: X server is down or not available" >&2
    exit 1
fi

if ! check_command "$BIN"; then
    echo "Error: $BIN not found" >&2
    exit 1
fi

OPTS=$(getopt -o d:m:wfst:yh \
    --long directory:,monitor:,window,focus,select,time:,yes,help \
    -n "$0" -- "$@")

if [[ $? -ne 0 ]]; then
    help
    exit 1
fi

eval set -- "$OPTS"

while true; do
    case "$1" in
        -m|--monitor)
            MONITOR="$2"
            shift 2
            ;;
        -w|--window)
            WINDOW=true
            shift
            ;;
        -f|--focus)
            FOCUS=true
            shift
            ;;
        -s|--select)
            SELECT=true
            shift
            ;;
        -t|--time)
            TIME="$2"
            shift 2
            ;;
        -y|--yes)
            SKIP_PROMPTS=true
            shift
            ;;
        -h|--help)
            help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            error "Internal getopt error"
            exit 1
            ;;
    esac
done

OUTPUT=${1:-screenshot_$(date +%Y-%m-%d_%H-%M-%S).png}

if [[ -f "$OUTPUT" ]] && ! confirm_action "Do you want to overwrite the file $(basename "$OUTPUT")?"; then
    exit 0
fi

if [[ -n "$MONITOR" ]]; then
    read -r W H X Y < <(get_monitor_geometry "$MONITOR")

    if [[ -z "$W" ]]; then
        echo "Error: Not found monitor $MONITOR" >&2
        exit 1
    fi
elif [[ "$WINDOW" = "true" ]]; then
    read -r X Y W H < <(get_selected_window_geometry)
elif [[ "$FOCUS" = "true" ]]; then
    read -r X Y W H < <(get_focused_window_geometry)
fi

if [[ -n "$W" ]]; then
    POSITION_OPTS+=(-a "$X,$Y,$W,$H")
elif [[ "$SELECT" = "true" ]]; then
    POSITION_OPTS+=(-s)
fi

if ! is_number "$TIME"; then
    echo "Error: Time in seconds must be a number"
    exit 1
fi

if "$BIN" "${POSITION_OPTS[@]}" -o -d "$TIME" "$OUTPUT"; then
    echo "$OUTPUT"
    exit 0
else
    echo "Error: scrot failed" >&2
    exit 1
fi
