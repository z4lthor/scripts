#!/bin/bash
#
# Loads AI model configuration profile into clipboard
# Author: z4lthor <z4lthor@gmail.com>
#

BASEDIR="$HOME/.config/ai"
LOADER="$BASEDIR/loader.txt"
PROFILE="$1"

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

(cat "$LOADER"; printf "\n---\n\n"; cat "$AGENT") | \
    sed 's/[[:space:]]*#.*//; /^[[:space:]]*$/d' | \
    xclip -sel clip

echo "Profile [$PROFILE] loaded and sanitized to clipboard."

exit 0
