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
VIDEO_FILTER_OPTS=(-vf "bwdif=mode=0:parity=auto:deint=1,format=yuv420p")
CONCAT=false
ACODEC="aac"
ABITRATE="128k"
AFREQ="48000"
ACHANNELS="2"
FOURCC=(-tag:v hvc1) # Codec ID: hev1 | hvc1
MP4FLAGS=(-movflags +faststart) # Relocates moov atom to beginning
VOB_MODE=false

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

help() {
cat <<EOF
Usage:
$(basename "$0") [OPTION]... INPUT OUTPUT
$(basename "$0") [OPTION]... -c INPUT... OUTPUT

Options:
-q, --quality VALUE              Set CRF 0-51 (default: $CRF)
-p, --preset PRESET              Set preset (default: $PRESET)
-s, --size WIDTH:HEIGHT          Set resolution (default: keep original size)
-c, --concat                     Set concat demuxer
--position [START][-END|+DURATION]

    START      : Timestamp (HH:MM:SS), defaults to 00:00:00 if omitted
    -END       : Stops at this timestamp  (HH:MM:SS).
    +DURATION  : Processes for this length (HH:MM:SS).

--audio-bitrate RATE             Set audio bitrate (default: $ABITRATE)
--audio-freq FREQUENCY           Set audio sampling frequency (default: $AFREQ)
--audio-channels CHANNELS        Set number of audio channels (default: $ACHANNELS)
-y, --yes                        Skip all prompts
-h, --help                       Show this help

Examples:
$(basename "$0") -q 23 --preset slow input.mkv output.mp4
$(basename "$0") -q 22 -s -1:1080 input.mp4 output.mp4
$(basename "$0") -q 21 -c VTS_01_1.VOB VTS_01_2.VOB VTS_01_3.VOB VTS_01_4.VOB movie.mp4
$(basename "$0") --position 01:10:08 input.avi output.mp4
$(basename "$0") --position 01:10:08-02:30:00 input.avi output.mp4
$(basename "$0") --position 01:10:08+00:00:30 input.avi output.avi
$(basename "$0") --position +1m input.avi output.avi
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

check_command() {
    local bin="$1"

    command -v "$bin" > /dev/null 2>&1
}

is_position() {
    local input="$1"

    [[ "$input" =~ ^([0-9]{1,2}(:[0-5][0-9]){0,2})?([+-][0-9]{1,2}(:[0-5][0-9]){0,2})?$ ]]
}

parse_position() {
    local input="$1"
    local START END DURATION

    ! is_position "$input" && return 1

    if [[ "$input" == *"+"* ]]; then
        START="${input%+*}"
        DURATION="${input#*+}"
    elif [[ "$input" == *"-"* && "$input" != -* ]]; then
        START="${input%-*}"
        END="${input#*-}"
    elif [[ "$input" == -* ]]; then
        START=""
        END="${input#-}"
    else
        START="$input"
    fi

    echo "${START:-00:00:00}|${END}|${DURATION}"
}

create_position_option() {
    local -n options=$1
    local parsed="$2"

    [[ -z "$parsed" ]] && return 0

    IFS='|' read -r start end duration <<< "$parsed"

    [[ -z "$start" || "$start" == "00:00:00" ]] || options+=(-ss "$start")
    
    if [[ -n "$end" ]]; then
        options+=(-to "$end")
    elif [[ -n "$duration" ]]; then
        options+=(-t "$duration")
    fi
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
    local filelist

    filelist=$(mktemp /tmp/filelist.XXXXXX) || return 1

    for input in "${inputs[@]}"; do
        printf "file '%s'\n" "$input" >> "$filelist"
    done

    trap 'rm -f "$filelist"' EXIT INT TERM

    echo "$filelist"
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

is_number() {
    local num=$1

    [[ "$num" =~ ^[0-9]+$ ]]
}

is_divisible_by_8() {
    local num=$1

    (( num % 8 == 0 ))
}

is_crf() {
    local crf="$1"

    is_number "$crf" && (( crf >= 0 && crf <= 51 ))
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

if ! check_command $BIN; then
    error "$BIN not found"
    exit 1
fi

OPTS=$(getopt -o q:p:s:cyh \
    --long quality:,preset:,size:,concat,position:,audio-bitrate:,audio-freq:,audio-channels:,yes,help \
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
        --position)
            POSITION="$2"
            shift 2
            ;;
        --audio-bitrate)
            ABITRATE="$2"
            shift 2
            ;;
        --audio-freq)
            AFREQ="$2"
            shift 2
            ;;
        --audio-channels)
            ACHANNELS="$2"
            shift 2
            ;;
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

if [[ $# -lt 2 ]]; then
    help
    exit 1
fi

if [[ "$CONCAT" = "true" && $# -le 2 ]] || [[ "$CONCAT" = "false" && $# -gt 2 ]]; then
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

POSITION_OPTS=()

if [[ -n "$POSITION" ]]; then
    if ! is_position "$POSITION"; then
        error "Wrong format. Position must be HH:MM:SS"
        exit 1
    fi

    parsed_opts=$(parse_position "$POSITION")
    create_position_option POSITION_OPTS "$parsed_opts"
fi

if [[ "$VOB_MODE" = "true" ]] && ! all_vobs "${INPUTS[@]}"; then
    error "VOB mode is on. All the input files must be VOBs"
    exit 1
fi

if ! is_crf "$CRF"; then
    error "Error: CRF must be a number between 0 and 51."
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

if [[ "$CONCAT" = "true" ]]; then
    # Use concat protocol for VOB files and the concat demuxer for everything else.
    if [[ "$VOB_MODE" = "true" ]]; then
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

if [[ -f "$OUTPUT" ]] && ! confirm_action "Do you want to overwrite the file $(basename "$OUTPUT")?"; then
    warn "Encoding aborted."
    exit 0
fi

# Check integrity
if confirm_action "Do you want to check integrity?"; then
    echo -n "Checking integrity ... "
    if ./check-video-integrity.sh "${INPUTS[@]}"> /dev/null 2>&1; then
        echo "OK"
    else
        echo "Fail"
        error "Encoding failed."
        exit 1
    fi
fi

# Check compatibility
if [[ "$CONCAT" = "true" ]] ; then
    echo -n "Checking compatibility ... "
    if ./check-video-compatibility.sh "${INPUTS[@]}"> /dev/null 2>&1; then
        echo "OK"
    else
        echo "Fail"
        error "Encoding failed."
        exit 1
    fi
fi

if [[ -n "$POSITION" ]]; then
    total=$(./get-total-duration.sh -p "$POSITION" "${INPUTS[@]}")
else
    total=$(./get-total-duration.sh "${INPUTS[@]}")
fi

if [[ $? -ne 0 || "$total" -eq 0 ]]; then
    error "Duration calculation failed"
    exit 1
fi

if ! confirm_action "Do you want to continue?"; then
    warn "Encoding aborted."
    exit 0
fi

while read -r line; do
    if [[ "$line" =~ out_time_ms=([0-9]+) ]]; then
        time=${line#*=}

        if is_number "$time"; then
            time_sec=$(( time / 1000000 ))
            percent=$(( time_sec * 100 / total ))
            (( percent > 100 )) && percent=100

        fi
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

    echo -ne "Encoding: ${percent}% Time: ${time_sec}s FPS: ${fps} Bitrate: ${bitrate} Size: ${size_mib}MiB\r"
done < <( "$BIN" -y -loglevel error \
            "${POSITION_OPTS[@]}" \
            "${INPUT_OPTS[@]}" \
            -c:v "$VCODEC" -crf "$CRF" -preset "$PRESET" \
            "${VIDEO_FILTER_OPTS[@]}" \
            -c:a "$ACODEC" -b:a "$ABITRATE" -ar "$AFREQ" -ac "$ACHANNELS" \
            "${FOURCC[@]}" \
            "${MP4FLAGS[@]}" \
            -progress pipe:1 \
            "$OUTPUT" 2>&1 )

if [[ $? -eq 0 ]]; then
    info "Encoding completed successfully."
else
    error "Encoding failed."
    exit 1
fi

exit 0
