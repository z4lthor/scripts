#!/bin/bash
#
# Creates a detailed inventory of a storage device
# Author: z4lthor <z4lthor@gmail.com>
#

get_physical_device() {
    local dev="$1"
    local node_name
    local slave
    local physical_name

    [[ ! -b "$dev" ]] && return 1

    node_name=$(basename "$(readlink -f "$dev")")

    if [[ -d "/sys/class/block/$node_name/slaves" ]] && [[ "$(ls -A "/sys/class/block/$node_name/slaves")" ]]; then
        slave=$(ls -1 "/sys/class/block/$node_name/slaves" | head -n1)
        physical_name=$(lsblk -dno PKNAME "/dev/$slave" 2>/dev/null | xargs)
        [[ -z "$physical_name" ]] && physical_name="$slave"
    else
        physical_name=$(lsblk -dno PKNAME "/dev/$node_name" 2>/dev/null | xargs)
        [[ -z "$physical_name" ]] && physical_name="$node_name"
    fi

    echo "/dev/$physical_name"
}

get_device_model() {
    local dev="$1"

    [[ ! -b "$dev" ]] && return 1

    device_model=$(smartctl -i "$dev" | grep -E "Model Number|Device Model" | cut -d: -f2 | xargs | tr ' ' '-')

    echo "$device_model"
}

get_device_size() {
    local dev="$1"

    [[ ! -b "$dev" ]] && return 1

    device_size=$(smartctl -i "$dev" | grep "User Capacity" | grep -oP '\[\K[^\]]+' | xargs | tr ' ' '-')

    echo "$device_size"
}

if [[ $EUID -ne 0 ]]; then
    echo "Error: Must be root" >&2
    exit 1
fi

if [[ "$#" -ne 1 ]]; then
    echo "Usage: $(basename "$0") DEVICE" >&2
    exit 1
fi

DEVICE="$1"
PHYSICAL_DEVICE=$(get_physical_device "$DEVICE")
DEVICE_MODEL=$(get_device_model "$PHYSICAL_DEVICE")
DEVICE_SIZE=$(get_device_size "$PHYSICAL_DEVICE")
DATE=$(date +%Y-%m-%d-%H-%M-%S)
OUTPUT_META=$(printf "%s_%s_%s_meta.txt" "$DEVICE_MODEL" "$DEVICE_SIZE" "$DATE")
OUTPUT_HASHES=$(printf "%s_%s_%s_hashes.txt" "$DEVICE_MODEL" "$DEVICE_SIZE" "$DATE")

if [[ ! -b "$DEVICE" ]]; then
    echo "Error: Device $DEVICE not found" >&2
    exit 1
fi

MOUNTPOINT=$(findmnt -no TARGET "$DEVICE")

if [[ -z "$MOUNTPOINT" ]] || ! mountpoint -q "$MOUNTPOINT"; then
    echo "Error: Device $DEVICE not mounted" >&2
    exit 1
fi

echo "Details"
echo "Device: $PHYSICAL_DEVICE"
echo "Model:  $DEVICE_MODEL"
echo "Size:   $DEVICE_SIZE"
echo "File Metadata: $OUTPUT_META"
echo "File Hashes: $OUTPUT_HASHES"

echo -n "Metadata file... "

if find "$MOUNTPOINT" -xdev -printf "%i|%y|%m|%u|%g|%s|%n|%D|%T@|%C@|%A@|%p|%l\0" > "$OUTPUT_META"; then
    echo "OK"
else
    echo "Failed"
    exit 1
fi


echo -n "Hashes file... "

if find "$MOUNTPOINT" -xdev -type f -print0 | xargs -0 sha256sum > "$OUTPUT_HASHES"; then
    echo "OK"
else
    echo "Failed"
    exit 1
fi

exit 0
