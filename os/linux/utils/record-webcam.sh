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
OUTPUT="${1:-webcam_$(date +%Y%m%d_%H%M%S).mp4}"
DURATION="${2:-0}"

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

if [[ ! -e "$DEVICE" ]]; then
    echo "Error: Device $DEVICE not found."
    exit 1
fi

RES=$(get_max_resolution "$DEVICE")
FPS=$(get_max_fps "$DEVICE" "$RES")
TIME=$([[ "$DURATION" -eq 0 ]] && echo "" || echo "-t $DURATION")

echo "Device: $DEVICE"
echo "Resolution: $RES"
echo "FPS: $FPS"
echo "Duration: ${DURATION}s (0=infinity)"
echo "Output: $OUTPUT"

echo "Recording (Ctrl+C to stop)..."

while read -r line; do
    if [[ "$line" =~ out_time=([0-9:.]+) ]]; then
        time=${line#*=}
    fi
    echo -ne "Time: ${time}s\r"
done < <( "$BIN" -y -loglevel error \
    -f v4l2 \
    -framerate "$FPS" \
    -video_size "$RES" \
    -i "$DEVICE" \
    $TIME \
    -c:v "$VCODEC" -crf "$CRF" -preset "$PRESET" \
    -pix_fmt "$PIX_FORMAT" \
    -progress pipe:1 \
    "$OUTPUT" 2>&1 )

echo "Ready on $OUTPUT"

exit 0
