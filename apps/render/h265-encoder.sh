#!/bin/bash
#
# Simple H.265/HEVC encoding script based on ffmpeg.
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/ffmpeg
VCODEC="libx265"
CRF=25
PRESET="medium"
CONCAT=false
ACODEC="aac"
ABITRATE="128k"
FOURCC="-tag:v hvc1" # Codec ID: hev1 | hvc1
MP4FLAGS="-movflags +faststart"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

help() {
cat <<EOF
Usage:
$0 [OPTION]... INPUT OUTPUT
$0 [OPTION]... -c INPUT... OUTPUT

Options:
-q, --quality VALUE     Set CRF 0-51 (default: $CRF)
-p, --preset PRESET     Set preset (default: $PRESET)
-c, --concat            Set concat demuxer
--audio-bitrate RATE    Set audio bitrate (default: $ABITRATE)
-h, --help              Show this help

Examples:
$0 -q 23 --preset slow input.mkv output.mp4
$0 -q 21 -c VTS_01_1.VOB VTS_01_2.VOB VTS_01_3.VOB VTS_01_4.VOB movie.mp4
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

if ! command -v $BIN > /dev/null 2>&1; then
    error "$BIN not found"
    exit 1
fi

OPTS=$(getopt -o q:p:ch \
    --long quality:,preset:,concat,audio-bitrate:,help \
    -n "$0" -- "$@")

if [[ $? -ne 0 ]]; then
    help
    exit 1
fi

eval set -- "$OPTS"

while true; do
    case "$1" in
        -q|--quality)
            CRF="$2"
            shift 2
            ;;
        -p|--preset)
            PRESET="$2"
            shift 2
            ;;
        -c|--concat)
            CONCAT=true
            shift
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

if [[ $# -lt 2 || ("$CONCAT" = "false" && $# -gt 2) ]]; then
    help
    exit 1
fi

ARGS=("$@")
OUTPUT=${ARGS[-1]}
unset 'ARGS[-1]'
INPUTS=("${ARGS[@]}")

for input in "${INPUTS[@]}"; do
    if [[ ! -f "$input" || "$input" == "$OUTPUT" ]]; then
        error "Input file is invalid: $input"
        exit 1
    fi
done

if [[ ! "$CRF" =~ ^[0-9]+$ ]]; then
    error "CRF must be a number."
    exit 1
fi

if (( CRF < 0 || CRF > 51 )); then
    error "Error: CRF must be between 0 and 51."
    exit 1
fi

FILELIST=$(mktemp /tmp/filelist.XXXXXX)
INPUTOPTS=(-i "${INPUTS[0]}")

if $CONCAT; then
    for input in "${INPUTS[@]}"; do
        printf "file '%s'\n" "$input" >> "$FILELIST"
    done
    INPUTOPTS=(-f concat -safe 0 -i $FILELIST)
fi

trap 'rm -f "$FILELIST"' EXIT INT TERM

info "Starting H.265 encode…"
info "CRF: $CRF"
info "Preset: $PRESET"
info "Concat: $CONCAT"
info "Audio bitrate: $ABITRATE"
info "Inputs: ${INPUTS[*]}"
info "Output: $OUTPUT"

if ! confirm_action "Do you want to continue?"; then
    warn "Encoding aborted."
    exit 0
fi

$BIN "${INPUTOPTS[@]}" \
    -c:v $VCODEC -crf $CRF -preset $PRESET \
    -c:a $ACODEC -b:a $ABITRATE \
    $FOURCC \
    $MP4FLAGS \
    "$OUTPUT"

if [[ $? -eq 0 ]]; then
    info "Encoding completed successfully."
else
    error "Encoding failed."
    exit 1
fi

exit 0
