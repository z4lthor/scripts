#!/bin/bash
#
# Simple H.265/HEVC encoding script based on ffmpeg.
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/ffmpeg
VCODEC="libx265"
CRF=25
PRESET="medium"
ACODEC="aac"
ABITRATE="128k"
HEVC_FOURCC="-tag:v hvc1"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

help() {
cat <<EOF
Usage:
$0 [options] <INPUT> <OUTPUT>

Options:
-c, --crf VALUE           Set CRF 0-51 (default: $CRF)
-p, --preset PRESET       Set preset (default: $PRESET)
--audio-bitrate RATE  Set audio bitrate (default: $ABITRATE)
-h, --help                Show this help

Examples:
$0 input.mkv output.mp4
$0 -c 23 --preset slow movie.mov out.mp4
EOF
}

error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

info() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

if ! command -v $BIN > /dev/null 2>&1; then
    error "$BIN not found"
    exit 1
fi

OPTS=$(getopt -o c:p:h \
    --long crf:,preset:,audio-bitrate:,help \
    -n "$0" -- "$@")

if [[ $? -ne 0 ]]; then
    help
    exit 1
fi

eval set -- "$OPTS"

while true; do
    case "$1" in
        -c|--crf)
            CRF="$2"
            shift 2
            ;;
        -p|--preset)
            PRESET="$2"
            shift 2
            ;;
        --audio-bitrate)
            ABITRATE="$2"
            shift 2
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

if [[ $# -ne 2 ]]; then
    error "Mandatory INPUT and OUTPUT"
    help
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

if [[ ! -f "$INPUT" ]]; then
    error "Input file not found: $INPUT"
    exit 1
fi

if [[ ! "$CRF" =~ ^[0-9]+$ ]]; then
    error "CRF must be a number."
    exit 1
fi

if (( CRF < 0 || CRF > 51 )); then
    error "Error: CRF must be between 0 and 51."
    exit 1
fi

info "Starting H.265 encode…"
info "CRF: $CRF"
info "Preset: $PRESET"
info "Audio bitrate: $ABITRATE"
info "Input: $INPUT"
info "Output: $OUTPUT"

$BIN -i "$INPUT" \
    -c:v $VCODEC -crf $CRF -preset $PRESET \
    -c:a $ACODEC -b:a $ABITRATE \
    $HEVC_FOURCC \
    "$OUTPUT"

if [[ $? -eq 0 ]]; then
    info "Encoding completed successfully."
else
    error "Encoding failed."
    exit 1
fi

exit 0

