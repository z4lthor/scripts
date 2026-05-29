#!/bin/bash
#
# Creates a detailed inventory of a storage device
# Author: z4lthor <z4lthor@gmail.com>
#

help() {
cat <<EOF
Usage: ${0##*/} [options] DEVICE [OUTPUT]

Options:
-h, --help              Show this help
EOF
}

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

get_output_filename() {
    local model="$1"
    local size="$2"
    local clean_model
    local timestamp

    [[ -z "$model" || -z "$size" ]] && return 1

    clean_model="${model//[^a-zA-Z0-9._-]/_}"
    clean_model=$(tr -s '_' <<< "$clean_model")
    timestamp=$(date +%Y%m%d_%H%M%S)

    printf "%s_%s_%s.tar.gz\n" "$clean_model" "$size" "$timestamp"
}

save_filesystem() {
    local mp="$1"
    local output="$2"

    if [[ -z "$mp" ]] || ! mountpoint -q "$mp"; then
        return 1
    fi

    [[ -z "$output" ]] && return 1

    local timestamp
    local device physical model uuid device_size
    local type inodes size used avail

    timestamp=$(date +%Y-%m-%dT%H:%M:%S%z)
    device=$(findmnt -no SOURCE "$mp")
    physical=$(get_physical_device "$device")
    model=$(get_device_model "$physical")
    uuid=$(findmnt -no UUID "$mp" 2>/dev/null)
    device_size=$(get_device_size "$physical")

    type=$(findmnt -no FSTYPE "$mp" 2>/dev/null)
    inodes=$(df "$mp" --output=iused 2>/dev/null | tail -n1 | xargs)
    size=$(df -h "$mp" --output=size 2>/dev/null | tail -n1 | xargs)
    used=$(df -h "$mp" --output=used 2>/dev/null | tail -n1 | xargs)
    avail=$(df -h "$mp" --output=avail 2>/dev/null | tail -n1 | xargs)

    {
        echo "Timestamp:    $timestamp"
        echo "Disk:         $model $device_size"
        echo "UUID:         ${uuid:-N/A}"
        echo "Type:         $type"
        echo "Inodes:       $inodes"
        echo "Size:         $size"
        echo "Used:         $used"
        echo "Avail:        $avail"
    } > "$output"
}

save_metadata() {
    local mp="$1"
    local output="$2"

    if [[ -z "$mp" ]] || ! mountpoint -q "$mp"; then
        return 1
    fi

    [[ -z "$output" ]] && return 1

    find "$mp" -xdev -printf "%i|%y|%m|%u|%g|%s|%n|%D|%T@|%C@|%A@|%p|%l\0" > "$output"
}

save_hashes() {
    local mp="$1"
    local output="$2"

    if [[ -z "$mp" ]] || ! mountpoint -q "$mp"; then
        return 1
    fi

    [[ -z "$output" ]] && return 1

    find "$mp" -xdev -type f -print0 | xargs -0 -P "$(nproc)" -n 100 sha256sum > "$output"
}

create_output() {
    local dir="$1"
    local output="$2"

    [[ ! -d "$dir" ]] && return 1

    [[ -z "$output" ]] && return 1

    tar -czf "$output" -C "$dir" .
}

if [[ $EUID -ne 0 ]]; then
    echo "Error: Must be root" >&2
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

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    help
    exit 1
fi

DEVICE="$1"
OUTPUT="$2"

if [[ ! -b "$DEVICE" ]]; then
    echo "Error: Device $DEVICE not found" >&2
    exit 1
fi

PHYSICAL_DEVICE=$(get_physical_device "$DEVICE")
DEVICE_MODEL=$(get_device_model "$PHYSICAL_DEVICE")
DEVICE_SIZE=$(get_device_size "$PHYSICAL_DEVICE")

if [[ -z "$OUTPUT" ]]; then
    OUTPUT=$(get_output_filename "$DEVICE_MODEL" "$DEVICE_SIZE")
fi

if [[ -f "$OUTPUT" ]]; then
    echo "Error: File $OUTPUT already exists" >&2
    exit 1
fi

MOUNTPOINT=$(findmnt -no TARGET "$DEVICE")

if [[ -z "$MOUNTPOINT" ]] || ! mountpoint -q "$MOUNTPOINT"; then
    echo "Error: Device $DEVICE not mounted" >&2
    exit 1
fi

echo "Device: $PHYSICAL_DEVICE"
echo "Model: $DEVICE_MODEL $DEVICE_SIZE"
echo "Mount point: $MOUNTPOINT"
echo

echo -n "Creating temporary directory ... "

if ! TMP_DIR=$(mktemp -d /tmp/storage_inventory_XXXXXX); then
    echo "Error: Could not create temporary directory." >&2
    exit 1
fi

echo "OK"

trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

OUTPUT_FS="$TMP_DIR/fs.txt"
OUTPUT_META="$TMP_DIR/meta.txt"
OUTPUT_HASHES="$TMP_DIR/hashes.txt"

echo -n "Create filesystem file ... "

if ! save_filesystem "$MOUNTPOINT" "$OUTPUT_FS"; then
    echo "Error: Failed to create the filesystem file." >&2
    exit 1
fi

echo "OK"

echo -n "Creating metadata file ... "

if ! save_metadata "$MOUNTPOINT" "$OUTPUT_META"; then
    echo "Error: Failed to create the metadata file." >&2
    exit 1
fi

echo "OK"

echo -n "Creating hashes file ... "

if ! save_hashes "$MOUNTPOINT" "$OUTPUT_HASHES"; then
    echo "Error: Failed to create the hashes file." >&2
    exit 1
fi

echo "OK"

echo -n "Creating compressed file ..."

if ! create_output "$TMP_DIR" "$OUTPUT"; then
    echo "Error: Failed to create the compressed inventory file." >&2
    exit 1
fi

echo "OK"

echo "Created inventory file $OUTPUT"

exit 0
