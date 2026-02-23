#!/bin/bash
#
# Record main screen on Xorg
# Author: z4lthor <z4lthor@gmail.com>
#

OUTPUT="$2"
FMT="x11grab"
VCODEC="libx264"
CRF=25
PRESET="veryfast"
PIXFMT="yuv420p"
FPS=30
OUTPUT=${1:-output-$(date +%Y-%m-%d_%H-%M-%S).mp4}

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

if [[ -f "$OUTPUT" ]] && ! confirm_action "Do you want to overwrite the file $(basename "$OUTPUT")?"; then
    echo "Recording aborted."
    exit 0
fi

read -r X Y W H < <(xdotool getwindowfocus getwindowgeometry --shell | \
    sed -n 's/^X=\([0-9]*\).*/\1/p;s/^Y=\([0-9]*\).*/\1/p;s/^WIDTH=\([0-9]*\).*/\1/p;s/^HEIGHT=\([0-9]*\).*/\1/p' | xargs)

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
