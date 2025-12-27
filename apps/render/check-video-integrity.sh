#!/bin/bash
#
# Check integrity of multiple video files
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/ffmpeg

RED="\e[31m"
GREEN="\e[32m"
RESET="\e[0m"

error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

info() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}

if ! command -v $BIN > /dev/null 2>&1; then
    error "$BIN not found"
    exit 1
fi

if [[ $# -eq 0 ]]; then
    error "Usage: $0 INPUT..."
    exit 1
fi

INPUTS=("$@")

for input in "${INPUTS[@]}"; do
    if [[ ! -f "$input" ]]; then
        error "Input file is invalid $input"
        exit 1
    fi
done

for file in "${INPUTS[@]}"; do
    info "Checking: $(basename "$file")"
    
    ERR_OUTPUT=$($BIN -v error -i "$file" -f null - 2>&1)
    
    if [[ $? -eq 0 ]] && [[ -z "$ERR_OUTPUT" ]]; then
        info "File $(basename "$file") integrity: OK"
    else
        error "File $(basename "$file") integrity: ERROR"
        if [[ -n "$ERR_OUTPUT" ]]; then
            error "  Details: $ERR_OUTPUT"
        fi
    fi
    echo ""
done

exit 0
