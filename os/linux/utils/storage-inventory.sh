#!/bin/bash
#
# Creates a detailed inventory of a storage device
# Author: z4lthor <z4lthor@gmail.com>
#

if [[ $EUID -ne 0 ]]; then
    echo "Error: Must be root" >&2
    exit 1
fi

if [[ "$#" -ne 2 ]]; then
    echo "Usage: $(basename "$0") DEVICE OUTPUT" >&2
    exit 1
fi

DEVICE="$1"
OUTPUT="$2"

if [[ ! -b "$DEVICE" ]]; then
    echo "Error: Device $DEVICE not found" >&2
    exit 1
fi

OUTPUT_DIR=$(dirname "$OUTPUT")

if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: Output directory $OUTPUT_DIR does not exists" >&2
    exit 1
fi

MOUNTPOINT=$(findmnt -no TARGET "$DEVICE")

if [[ -z "$MOUNTPOINT" ]] || ! mountpoint -q "$MOUNTPOINT"; then
    echo "Error: Device $DEVICE not mounted" >&2
    exit 1
fi

echo -n "Making $DEVICE inventory ... "

if find "$MOUNTPOINT" -xdev -printf "%i|%y|%m|%u|%g|%s|%A@|%p|%l\0" > "$OUTPUT"; then
    echo "OK"
    echo
    echo "Output: $OUTPUT"
    echo "Entries: $(wc -l < "$OUTPUT")"
else
    echo "Fail" >&2
    exit 1
fi

exit 0
