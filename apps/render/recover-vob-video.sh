#!/bin/bash
#
# Recover VOB container through lossless MPEG2-TS remuxing
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/ffmpeg

check_command() {
    local bin="$1"

    command -v "$bin" > /dev/null 2>&1
}

if ! check_command $BIN; then
    echo "$BIN not found"
    exit 1
fi

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

is_vob() {
    local file="$1"
    [[ "${file,,}" == *.vob ]]
}

create_temporary_directory() {
    TMPDIR=$(mktemp -d) || return 1

    trap 'echo "Cleaning up ..."; rm -rf "$tmpdir"' EXIT INT TERM
}

if [[ $# -ne 2 ]]; then
    echo "Usage: $(basename "$0") INPUT OUTPUT"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

if [[ ! -s "$INPUT" ]] || ! is_vob "$INPUT"; then
    echo "Error: Input file is invalid: $INPUT"
    exit 1
fi

if [[ "$INPUT" == "$OUTPUT" ]]; then
    echo "Error: Output file is invalid: $OUTPUT"
    exit 1
fi

if [[ -f "$OUTPUT" ]] && ! confirm_action "Do you want to overwrite the file $(basename "$OUTPUT")?"; then
    warn "Encoding aborted."
    exit 0
fi

BASENAME=$(basename "$INPUT")
TMPFILE="${BASENAME%.*}.ts"

create_temporary_directory

if [[ $? -eq 1 ]]; then
    echo "Error: Temporary directory failed"
    exit 1
fi

echo "Encoding MPEG2-TS ..."

# Phase 1: Sanitize and Rebuild Timestamps
# 1. -fflags +genpts: Regenerates missing or corrupt Presentation Time Stamps (PTS).
# 2. -map 0:v -map 0:a?: Selects all video and audio streams, ignoring problematic 
#    data/subtitle streams that often cause "Invalid media type" errors.
# 3. -f mpegts: Wraps the content in an MPEG Transport Stream, which is more 
#    resilient to corruption and helps align broken stream sync.
"$BIN" -hide_banner -loglevel quiet -y -fflags +genpts \
       -i "$INPUT" \
       -c copy -map 0:v -map 0:a? -f mpegts \
       "$TMPDIR"/"$TMPFILE"

if [[ $? -eq 1 ]]; then
    echo "Error: encoding failed"
    exit 1
fi

echo "Recovering VOB ..."

# Phase 2: Final Remux back to VOB container
# 1. -map 0:v:0 -map 0:a?: Ensures only the primary video and available audio 
#    tracks from the sanitized TS file are carried over.
# 2. -c copy: Performs a lossless stream copy (remuxing) without re-encoding, 
#    preserving original MPEG-2 and AC3 quality.
# 3. -f vob: Outputs a standard Program Stream (VOB) with corrected headers.
"$BIN" -hide_banner -loglevel quiet -y \
       -i "$TMPDIR"/"$TMPFILE" \
       -map 0:v:0 -map 0:a? \
       -c copy \
       -f vob \
       "$OUTPUT"

if [[ $? -eq 1 ]]; then
    echo "Error: recovery failed"
    exit 1
fi

echo "Recovery completed successfully."

exit 0
