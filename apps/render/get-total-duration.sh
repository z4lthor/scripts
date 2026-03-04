#!/bin/bash
#
# Calculate total duration of video inputs in microseconds.
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/ffprobe

help() {
cat <<EOF
Usage:
$(basename "$0") [OPTION]... INPUT...

Options:
-p, --position [START][-END|+DURATION]

    START      : Timestamp (HH:MM:SS), defaults to 00:00:00 if omitted
    -END       : Stops at this timestamp  (HH:MM:SS).
    +DURATION  : Processes for this length (HH:MM:SS).

-h, --help       Show this help
EOF
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

    ! is_position $input && return 1

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

to_seconds() {
    local position="$1"
    local seconds=0

    ! is_position $position && return 1

    IFS=':' read -ra parts <<< "$position"

    local count=${#parts[@]}

    case $count in
        1)
            seconds="${parts[0]}"
            ;;
        2)
            seconds=$(( parts[1] + 60 * parts[0] ))
            ;;
        3)
            seconds=$(( parts[2] + 60 * parts[1] + 60 * 60 * parts[0] ))
            ;;
    esac

    echo "$seconds"
}

position_to_seconds() {
    local position="$1"
    local total="$2"
    local start_sec=0
    local end_sec=0
    local duration_sec=0

    IFS="|" read -r START END DURATION <<< "$position"

    [[ -n "$START" ]] && start_sec=$(to_seconds "$START")
    [[ -n "$END" ]] && end_sec=$(to_seconds "$END")
    [[ -n "$DURATION" ]] && duration_sec=$(to_seconds "$DURATION")
    
    (( start_sec > end_sec )) && return 1
    (( end_sec > total || start_sec + duration_sec > total )) && return 1

    seconds=$(( end_sec - start_sec + duration_sec ))

    echo "$seconds"
}

sum_file_duration() {
    local inputs=("$@")
    local total=0
    local error_found=0

    for input in "${inputs[@]}"; do
        if [[ -f "$input" ]]; then
            duration=$(LC_ALL=C ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input")

            if [[ $duration =~ ^[0-9.]+$ ]]; then
                us=$(awk -v d="$duration" 'BEGIN { printf "%.0f", d * 1000000 }')
                total=$((total + us))
            else
                echo "Error: Cannot get the duration of $input" >&2
                error_found=1
            fi
        else
            echo "Error: File not found: $input" >&2
            error_found=1
        fi
    done

    [[ "$error_found" -eq 1 ]] && return 1

    echo "$(( total / 1000000 ))"
}

if ! check_command $BIN; then
    echo "$BIN not found" >&2
    exit 1
fi

OPTS=$(getopt -o p:,h \
    --long position:,help \
    -n "$0" -- "$@")

if [[ $? -ne 0 ]]; then
    help
    exit 1
fi

eval set -- "$OPTS"

while true; do
    case "$1" in
        -p|--position)
            POSITION="$2"
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

if [[ $# -eq 0 ]]; then
    help
    exit 1
fi

INPUTS=("$@")

duration=$(sum_file_duration "${INPUTS[@]}")

if [[ $? -eq 1 ]]; then
    echo "Error: Cannot get the total duration" >&2
    exit 1
fi

if [[ -n "$POSITION" ]]; then
    if ! is_position "$POSITION"; then
        echo "Error: Wrong format. Position must be HH:MM:SS"
        exit 1
    fi

    parsed_position=$(parse_position $POSITION)
    seconds=$(position_to_seconds "$parsed_position" "$duration")

    if [[ $? -eq 1 ]]; then
        echo "Error: Wrong values. Position is out of the limits."
        exit 1
    fi

    duration="$seconds"
fi

echo "$duration"

exit 0
