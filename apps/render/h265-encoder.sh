#!/bin/bash
#
# Simple H.265/HEVC encoding script based on ffmpeg.
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/ffmpeg
VCODEC="libx265"
CRF=25
PRESET="medium"
# Deinterlace only if needed using the BWDIF algorithm (superior to YADIF), 
# maintaining original frame rate (mode=0) and ensuring universal YUV420p 
# compatibility for the output.
VIDEO_FILTER_OPTS=(-vf "bwdif=filter=complex:mode=0:parity=auto:deint=1,format=yuv420p")
CONCAT=false
ACODEC="aac"
ABITRATE="128k"
FOURCC="-tag:v hvc1" # Codec ID: hev1 | hvc1
MP4FLAGS="-movflags +faststart"
VOB_MODE=false

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
-s, --size WIDTH:HEIGHT Set resolution (default: keep original size)
-c, --concat            Set concat demuxer
--audio-bitrate RATE    Set audio bitrate (default: $ABITRATE)
-h, --help              Show this help

Examples:
$0 -q 23 --preset slow input.mkv output.mp4
$0 -q 22 -s -1:1080 input.mp4 output.mp4
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

is_vob() {
    local file="$1"
    [[ "${file,,}" == *.vob ]]
}

all_vobs() {
    local inputs=("$@")

    for input in "${inputs[@]}"; do
        if ! is_vob "$input"; then
            return 1;
        fi
    done

    return 0;
}

create_temporary_filelist() {
    local inputs=("$@")
    local filelist=$(mktemp /tmp/filelist.XXXXXX)

    for input in "${inputs[@]}"; do
        printf "file '%s'\n" "$input" >> "$filelist"
    done

    trap 'rm -f "$filelist"' EXIT INT TERM

    echo "$filelist"
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

is_number() {
    local num=$1
    [[ "$num" =~ ^[0-9]+$ ]]
}

is_divisible_by_8() {
    local num=$1
    (( num % 8 == 0 ))
}

is_resolution_format() {
    local size=$1
    
    IFS=':' read -r WIDTH HEIGHT <<< "$size"
    
    [[ -z "$WIDTH" ]] || [[ -z "$HEIGHT" ]] && return 1
    
    if [[ "$WIDTH" == "-1" ]]; then
        is_number "$HEIGHT" && is_divisible_by_8 "$HEIGHT"
    elif [[ "$HEIGHT" == "-1" ]]; then
        is_number "$WIDTH" && is_divisible_by_8 "$WIDTH"
    else
        is_number "$WIDTH" && is_divisible_by_8 "$WIDTH" && \
        is_number "$HEIGHT" && is_divisible_by_8 "$HEIGHT"
    fi
}

if ! command -v $BIN > /dev/null 2>&1; then
    error "$BIN not found"
    exit 1
fi

OPTS=$(getopt -o q:p:s:ch \
    --long quality:,preset:,size:,concat,audio-bitrate:,help \
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
        -s|--size)
            SIZE="$2"
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

# Normalizing path names
OUTPUT=$(realpath -m "$OUTPUT")

for i in "${!INPUTS[@]}"; do
  INPUTS[$i]=$(realpath -m "${INPUTS[$i]}")
done

for input in "${INPUTS[@]}"; do
    if [[ ! -f "$input" || "$input" == "$OUTPUT" ]]; then
        error "Input file is invalid: $(basename "$input")"
        exit 1
    fi
    if is_vob "$input"; then
        VOB_MODE=true
    fi
done

if $VOB_MODE && ! all_vobs "${INPUTS[@]}"; then
    error "VOB mode is on. All the input files must be VOBs"
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

if [[ -n "$SIZE" ]]; then
    if ! is_resolution_format "$SIZE"; then
        error "Error: Wrong format. Use -s WIDTH:HEIGHT (e.g., -s 1920:1080)"
        exit 1
    fi
    # Append scaling to the existing filter chain using Lanczos for high-quality resampling
    VIDEO_FILTER_OPTS[1]="${VIDEO_FILTER_OPTS[1]},scale=$SIZE:flags=lanczos"
fi

INPUT_OPTS=(-i "${INPUTS[0]}")

if $CONCAT; then
    # Use concat protocol for VOB files and the concat demuxer for everything else.
    if $VOB_MODE; then
        INPUT_OPTS=(-i "concat:$(IFS="|"; echo "${INPUTS[*]}")")
    else
        INPUT_OPTS=(-f concat -safe 0 -i "$(create_temporary_filelist "${INPUTS[@]}")")
    fi
fi

info "Starting H.265 encode…"
info "CRF: $CRF"
info "Preset: $PRESET"
[[ -n "$SIZE" ]] && info "Size: $SIZE"
info "Concat: $CONCAT"
info "VOB mode: $VOB_MODE"
info "Audio bitrate: $ABITRATE"
if [[ ${#INPUTS[@]} -eq 1 ]]; then
    info "Input: ${INPUTS[*]}"
else
    info "Inputs:"
    for k in "${!INPUTS[@]}"; do
        info "\t[$((k + 1))]: $(basename "${INPUTS[$k]}")"
    done
fi
info "Output: $(basename "$OUTPUT")"

# Check integrity
echo -n "Checking integrity ... "
if ./check-video-integrity.sh "${INPUTS[@]}"> /dev/null 2>&1; then
    echo "OK"
else
    echo "Fail"
    error "Encoding failed."
    exit 1
fi

if ! confirm_action "Do you want to continue?"; then
    warn "Encoding aborted."
    exit 0
fi

$BIN "${INPUT_OPTS[@]}" \
    -c:v $VCODEC -crf $CRF -preset $PRESET \
    "${VIDEO_FILTER_OPTS[@]}" \
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
