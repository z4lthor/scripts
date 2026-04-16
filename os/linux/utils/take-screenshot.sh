#!/bin/bash
#
# Take a screenshot of the entire desktop and save it as PNG
# Author: z4lthor <z4lthor@gmail.com>
#

DEFDIR=$HOME/Pictures/Screenshots

help() {
cat <<EOF
Usage:
$(basename "$0") [OPTION]... [DIRECTORY]

Options:
-h, --help  Show this help
EOF
}

if [[ -z "$DISPLAY" ]] || ! xset q >/dev/null 2>&1; then
    echo "Error: X server is down or not available" >&2
    exit 1
fi

OPTS=$(getopt -o h \
    --long help \
    -n "$0" -- "$@")

if [[ $? -ne 0 ]]; then
    help
    exit 1
fi

eval set -- "$OPTS"

while true; do
    case "$1" in
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

DSTDIR=${1:-$DEFDIR}

if [[ ! -d "$DSTDIR" ]]; then
    echo "Directory $DSTDIR does not exists. Creating it..."
    if ! mkdir -p "$DSTDIR"; then
        echo "Error: Failed to create directory $DSTDIR" >&2
        exit 1
    fi
fi

if [[ ! -w "$DSTDIR" ]]; then
    echo "Error: Directory $DSTDIR is not writable" >&2
    exit 1
fi

FILE="$DSTDIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

if scrot -d 1 "$FILE"; then
    echo "$FILE"
    exit 0
else
    echo "Error: scrot failed" >&2
    exit 1
fi
