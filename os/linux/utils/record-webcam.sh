#!/bin/bash
#
# Record webcasm on Xorg
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/ffmpeg
VCODEC="libx264"
CRF=25
PRESET="ultrafast"
PIX_FORMAT="yuv420p"
DEVICE="/dev/video0"
FFMPEG_PID=""
FIFO=$(mktemp -u /tmp/record-screen_progress.XXXXXX)

mkfifo "$FIFO"

help() {
cat <<EOF
Usage:
$(basename "$0") [OPTION]... [OUTPUT] [DURATION]

Options:
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

get_max_resolution() {
    local device="$1"

    [[ -z "$device" ]] && return 1

    res=$(v4l2-ctl --device="$device" --list-formats-ext | grep "Size: Discrete" | awk '{print $3}' | sort -t'x' -k1,1nr -k2,2nr | head -n 1)

    echo "$res"
}

get_max_fps() {
    local device="$1"
    local res="$2"

    [[ -z "$device" || -z "$res" ]] && return 1

    fps=$(v4l2-ctl --device="$device" --list-formats-ext | sed -n "/$res/,/Size:/p" | grep "fps" | grep -oP '\d+\.\d+' | sort -rn | head -n 1 | cut -d. -f1)

    echo "$fps"
}

finish() {
    echo -e "\n\nStopping recording..."

    trap '' SIGINT

    if [[ -n "$FFMPEG_PID" ]]; then
        echo "Waiting for ffmpeg to finalize file..."

        wait "$FFMPEG_PID" 2>/dev/null
    fi

    rm -f "$FIFO"

    echo "File saved to $OUTPUT ($(du -sh "$OUTPUT" | awk '{print $1}'))"
    exit 0
}

if ! check_command $BIN; then
    echo "$BIN not found" >&2
    exit 1
fi

OPTS=$(getopt -o yh \
    --long yes,help \
    -n "$0" -- "$@")

if [[ $? -ne 0 ]]; then
    help
    exit 1
fi

eval set -- "$OPTS"

while true; do
    case "$1" in
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

OUTPUT=${1:-webcam_$(date +%Y-%m-%d_%H-%M-%S).mp4}
DURATION="${2:-0}"

if [[ ! -e "$DEVICE" ]]; then
    echo "Error: Device $DEVICE not found."
    exit 1
fi

if ! v4l2-ctl --device="$DEVICE" --all 2>/dev/null | grep -q "Video Capture"; then
    echo "Error: $DEVICE not supports video capture."
    exit 1
fi

RES=$(get_max_resolution "$DEVICE")
FPS=$(get_max_fps "$DEVICE" "$RES")
TIME=$([[ "$DURATION" -eq 0 ]] && echo "" || echo "-t $DURATION")

if [[ -f "$OUTPUT" ]] && ! confirm_action "Do you want to overwrite the file $(basename "$OUTPUT")?"; then
    echo "Recording aborted."
    exit 0
fi

trap finish SIGINT

echo "Device: $DEVICE"
echo "Resolution: $RES"
echo "FPS: $FPS"
echo "Duration: ${DURATION}s (0=infinity)"
echo "Output: $OUTPUT"

echo "Recording (ctrl+c to stop)..."

"$BIN" -y -loglevel error \
    -f v4l2 \
    -framerate "$FPS" \
    -video_size "$RES" \
    -i "$DEVICE" \
    $TIME \
    -c:v "$VCODEC" -crf "$CRF" -preset "$PRESET" \
    -pix_fmt "$PIX_FORMAT" \
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
