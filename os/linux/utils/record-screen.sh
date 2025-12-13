#!/bin/env bash
#
# Record main screen on Xorg
# Author: z4lthor <z4lthor@gmail.com>
#

RES="$1"
OUTPUT="$2"

if [[ $# -ne 2 ]]; then
    echo "$0 <RESOLUTION> <OUTPUT>"
    exit 1
fi

ffmpeg \
  -video_size $RES \
  -framerate 30 \
  -f x11grab \
  -i :0.0+0,0 \
  -c:v libx264 \
  -preset veryfast \
  -crf 23 \
  -pix_fmt yuv420p \
  $OUTPUT

exit 0
