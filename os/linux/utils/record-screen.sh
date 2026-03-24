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
WINDOW=false
FOCUS=false
FFMPEG_PID=""
FIFO=$(mktemp -u /tmp/record-screen_progress.XXXXXX)

mkfifo "$FIFO"

help() {
cat <<EOF
Usage:
$(basename "$0") [OPTION]... [OUTPUT]

Options:
-m, --monitor MONITOR       Record monitor MONITOR
-w, --window                Record selected window
-f, --focus                 Record focused window
-h, --help                  Show this help

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

finish() {
    echo -e "\n\nStopping recording..."

    trap '' SIGINT

    if [[ -n "$ffmpeg_pid" ]]; then
        kill -SIGINT "$FFMPEG_PID" 2>/dev/null

        echo "Waiting for ffmpeg to finalize file..."

        wait "$FFMPEG_PID" 2>/dev/null
    fi

    rm -f "$FIFO"

    echo "File saved to $OUTPUT ($(du -sh "$OUTPUT" | awk '{print $1}'))"
    exit 0
}

if [[ -z "$DISPLAY" ]] || ! xset q >/dev/null 2>&1; then
    echo "Error: X server is down or not available" >&2
    exit 1
fi

if ! check_command $BIN; then
    echo "$BIN not found" >&2
    exit 1
fi

OPTS=$(getopt -o m:wfh \
    --long monitor:,window,focus,help \
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

if [[ -n "$MONITOR" ]] && [[ "$WINDOW" = "true" || "$FOCUS" = "true" ]]; then
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
        echo "Error: Not found monitor $MONITOR" >&2
        exit 1
    fi
elif [[ "$WINDOW" = "true" ]]; then
    read -r X Y W H < <(xdotool selectwindow getwindowgeometry --shell | \
        sed -n 's/^X=\([0-9]*\).*/\1/p;s/^Y=\([0-9]*\).*/\1/p;s/^WIDTH=\([0-9]*\).*/\1/p;s/^HEIGHT=\([0-9]*\).*/\1/p' | xargs)
elif [[ "$FOCUS" = "true" ]]; then
    read -r X Y W H < <(xdotool getwindowfocus getwindowgeometry --shell | \
        sed -n 's/^X=\([0-9]*\).*/\1/p;s/^Y=\([0-9]*\).*/\1/p;s/^WIDTH=\([0-9]*\).*/\1/p;s/^HEIGHT=\([0-9]*\).*/\1/p' | xargs)
else
    read W H X Y < <(xrandr --query | awk '
    $2 == "connected" && /[0-9]+x[0-9]+\+[0-9]+\+[0-9]+/ {
        # Search geometry (i.e. 1920x1080+0+0)
        match($0, /([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)/, m)

        w = m[1]; h = m[2]; x = m[3]; y = m[4]

        if (x + w > max_w) max_w = x + w
            if (y + h > max_h) max_h = y + h
            } 
    END { print max_w, max_h, 0, 0 }')
fi

trap finish SIGINT

echo "Recording ..."

"$BIN" -y -loglevel error \
    -video_size "${W}x${H}" \
    -framerate "$FPS" \
    -f "$FMT" \
    -i ":0.0+$X,$Y" \
    -c:v "$VCODEC" \
    -preset "$PRESET" \
    -crf "$CRF" \
    -pix_fmt "$PIXFMT" \
    -progress "$FIFO" \
    "$OUTPUT" 2>/dev/null &

FFMPEG_PID=$!

while read -r line; do
    if [[ "$line" =~ out_time=([0-9:.]+) ]]; then
        time=${line#*=}
        time=${time%.*}
    fi

    if [[ "$line" =~ fps=([0-9.]+) ]]; then
        fps=${line#*=}
    fi

    if [[ "$line" =~ bitrate=([0-9.]+) ]]; then
        bitrate=${line#*=}
    fi

    if [[ "$line" =~ total_size=([0-9.]+) ]]; then
        size=${line#*=}
        size_mib=$(echo "scale=2; $size / 1048576" | bc)
    fi

    if [[ "$line" == "progress=end" ]]; then
        break
    fi

    echo -ne "Time: ${time}s FPS: ${fps} Bitrate: ${bitrate} Size: ${size_mib}MiB\r"
done < "$FIFO"

wait "$FFMPEG_PID"
