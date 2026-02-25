#!/bin/bash
#
# Record webcasm on Xorg
# Author: z4lthor <z4lthor@gmail.com>
#

DEVICE="/dev/video0"
RES="1280x720"
FPS=30
OUTPUT="${1:-output_$(date +%Y%m%d_%H%M%S).mp4}"
DURATION="${2:-0}"

echo "Device: $DEVICE"
echo "Resolution: $RES"
echo "FPS: $FPS"
echo "Duration: ${DURATION}s (0=infinity)"
echo "Output: $OUTPUT"

if [ "$DURATION" = "0" ]; then
    echo "Recording (Ctrl+C to stop)..."
    ffmpeg -f v4l2 -framerate "$FPS" -video_size "$RES" -i "$DEVICE" \
        -c:v libx264 -pix_fmt yuv420p \
        -preset veryfast -crf 25 "$OUTPUT"
else
    echo "Recording $DURATION seconds..."
    ffmpeg -f v4l2 -framerate $FPS -video_size $RES -i $DEVICE \
        -t $DURATION -c:v libx264 -pix_fmt yuv420p \
        -preset veryfast -crf 25 $OUTPUT
fi

echo "Ready on $OUTPUT"

exit 0
