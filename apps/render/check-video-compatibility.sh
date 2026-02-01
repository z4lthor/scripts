#!/bin/bash
#
# Check compatibility of multiple video files
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/ffprobe
INPUTS=("$@")

get_video_fingerprint() {
    local file="$1"
    local video_fp=$($BIN -v error -analyzeduration 5M -probesize 5M \
        -select_streams v:0 -show_entries stream=width,height,pix_fmt,r_frame_rate \
        -of csv=p=0 "$file" 2>/dev/null | sed 's/,$//')
    local audio_fp=$($BIN -v error -analyzeduration 5M -probesize 5M \
        -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels \
        -of csv=p=0 "$file" 2>/dev/null)

    if [[ -n "$video_fp" && -n "$audio_fp" ]]; then
        echo "${video_fp//[$'\r\n']/},${audio_fp//[$'\r\n']/}"
    else
        echo "${video_fp:-no_video},${audio_fp:-no_audio}"
    fi
}

if ! command -v $BIN > /dev/null 2>&1; then
    echo "$BIN not found" >&2
    exit 1
fi

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 INPUT..." >&2
    exit 1
fi
#
# Normalizing path names
for k in "${!INPUTS[@]}"; do
  INPUTS[$k]=$(realpath -m "${INPUTS[$k]}")
done

for input in "${INPUTS[@]}"; do
    if [[ ! -f "$input" ]]; then
        echo "Input file is invalid: $(basename "$input")"
        exit 1
    fi
done

echo "Checking compatibility of ${#INPUTS[@]} file(s)..."

for input in "${INPUTS[@]}"; do
    cur_fp=$(get_video_fingerprint "$input")

    if [[ -z "$MAIN_FP" ]]; then
        MAIN_FP="$cur_fp"
        echo "Fingerprint: $MAIN_FP"
    fi

    if [[ "$cur_fp" == "$MAIN_FP" ]]; then
        echo "$(basename "$input") : OK"
    else
        echo "$(basename "$input") : Wrong"
        echo "$cur_fp != $MAIN_FP"
        exit 1
    fi
done

exit 0
