#!/bin/bash
#
# Loads AI model configuration profile into clipboard
# Author: z4lthor <z4lthor@gmail.com>
#

XCLIP_BIN=/usr/bin/xclip
WL_COPY_BIN=/usr/bin/wl-copy
BASEDIR="$HOME/.config/ai"
LOADER="$BASEDIR/loader.txt"
PROFILE="$1"

check_command() {
    local bin="$1"

    command -v "$bin" > /dev/null 2>&1
}

copy() {
    if check_command "$WL_COPY_BIN"; then
        "$WL_COPY_BIN"
    elif check_command "$XCLIP_BIN"; then
        "$XCLIP_BIN" -sel clip
    else
        cat
    fi
}

validate() {
    local profile="$1"

    yq '.' "$profile" > /dev/null 2>&1
}

if [[ $# -eq 0 ]]; then
    echo "Usage: $(basename "$0") PROFILE"
    exit 1
fi

if [[ ! -d "$BASEDIR" ]]; then
    echo "Error: $BASEDIR not found"
    exit 1
fi

if [[ ! -f "$LOADER" ]]; then
    echo "Error: $(basename "$LOADER") not found in $BASEDIR"
    exit 1
fi

AGENT="$BASEDIR/profiles/$PROFILE.yaml"

if [[ ! -f "$AGENT" ]]; then
    echo "Error: Profile '$PROFILE.yaml' not found in $BASEDIR/profiles/"
    exit 1
fi

if ! validate "$AGENT"; then
    echo "Error: Invalid profile $PROFILE.yaml"
    exit 1
fi

(cat "$LOADER"; printf "\n---\n\n"; cat "$AGENT") | \
sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' | \
copy

echo "Profile [$PROFILE] loaded and sanitized to clipboard."

exit 0
