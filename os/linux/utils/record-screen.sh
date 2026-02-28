#!/bin/bash
#
# Record main screen on Xorg
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/ffmpeg
FMT="x11grab"
VCODEC="libx264"
CRF=25
PRESET="veryfast"
PIXFMT="yuv420p"
FPS=30
FOCUS=false

help() {
cat <<EOF
Usage:
$0 [OPTION]... [OUTPUT]

Options:
-m, --monitor MONITOR       Record monitor MONITOR
-f, --focus                 Record focused window

* The options --monitor and --focus are mutually exclusive.
EOF
}

check_command() {
    local bin="$1"

    command -v "$bin" > /dev/null 2>&1
}

confirm_action() {
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

if ! check_command $BIN; then
    error "$BIN not found"
    exit 1
fi

OPTS=$(getopt -o m:fh \
    --long monitor:,focus,help \
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
        -f|--focus)
            FOCUS=true
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

OUTPUT=${1:-screen_output_$(date +%Y-%m-%d_%H-%M-%S).mp4}

if [[ -n "$MONITOR" && "$FOCUS" = "true" ]]; then
    help
    exit 1
fi

if [[ -f "$OUTPUT" ]] && ! confirm_action "Do you want to overwrite the file $(basename "$OUTPUT")?"; then
    echo "Recording aborted."
    exit 0
fi

if [[ -n "$MONITOR" ]]; then
    read -r W H X Y < <(xrandr --query | grep "^$MONITOR" | grep -oP '\d+x\d+\+\d+\+\d+' | tr 'x+' ' ')

    if [ -z "$W" ]; then
        echo "Error: Not found monitor $MONITOR"
        exit 1
    fi
fi

if [[ "$FOCUS" = "true" ]]; then
    read -r X Y W H < <(xdotool getwindowfocus getwindowgeometry --shell | \
        sed -n 's/^X=\([0-9]*\).*/\1/p;s/^Y=\([0-9]*\).*/\1/p;s/^WIDTH=\([0-9]*\).*/\1/p;s/^HEIGHT=\([0-9]*\).*/\1/p' | xargs)
fi

ffmpeg \
  -video_size "${W}x${H}" \
  -framerate "$FPS" \
  -f "$FMT" \
  -i ":0.0+$X,$Y" \
  -c:v "$VCODEC" \
  -preset "$PRESET" \
  -crf "$CRF" \
  -pix_fmt "$PIXFMT" \
  "$OUTPUT"

exit 0
