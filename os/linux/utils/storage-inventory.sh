#!/bin/bash
#
# Creates a detailed inventory of a storage device
# Author: z4lthor <z4lthor@gmail.com>
#

FAST=false
SKIP_HASHES=false
THRESHOLD=$(( 1024 * 1024 ))

help() {
cat <<EOF
Usage: ${0##*/} [options] DEVICE [OUTPUT]

Options:
-f --fast               Compute a partial hash for files larger than 1 MB, reading
                        4096 bytes from the middle and 4096 bytes from the end.
                        Files smaller than 1 MB are always fully hashed.
                        Faster than full hashing but may produce false positives.
-t --threshold BYTES    File size threshold in bytes for partial hashing.
                        Files larger than BYTES are hashed partially (middle
                        and end chunks). Only valid combined with --fast.
                        Default: 1048576 (1 MB).
-s, --skip-hashes       Skip hashes file creation
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

calc_hash() {
    local file="$1"
    local size
    local chunk=4096

    size=$(stat -c%s "$file")

    if [[ "$FAST" = "false" ]] || (( size <= THRESHOLD )); then
        sha256sum "$file"
    else
        local mid=$(( size / 2 ))
        (
            dd if="$file" bs=1 skip="$mid"              count="$chunk" 2>/dev/null
            dd if="$file" bs=1 skip=$(( size - chunk )) count="$chunk" 2>/dev/null
        ) | sha256sum | FILE="$file" awk '{print $1 " " ENVIRON["FILE"]}'
    fi
}

export -f calc_hash

save_hashes() {
    local mp="$1"
    local output="$2"

    if [[ -z "$mp" ]] || ! mountpoint -q "$mp"; then
        return 1
    fi

    [[ -z "$output" ]] && return 1

    find "$mp" -xdev -type f -print0 | \
        xargs -0 -P "$(nproc)" -n 1 bash -c 'calc_hash "$@"' _ > "$output"
}

create_output() {
    local dir="$1"
    local output="$2"

    [[ ! -d "$dir" ]] && return 1

    [[ -z "$output" ]] && return 1

    tar -czf "$output" -C "$dir" .
}

is_positive_integer() {
    local num=$1
    [[ "$num" =~ ^[1-9][0-9]*$ ]]
}

if [[ $EUID -ne 0 ]]; then
    echo "Error: Must be root" >&2
    exit 1
fi

OPTS=$(getopt -o ft:sh \
    --long fast,threshold:,skip-hashes,help \
    -n "$0" -- "$@")

if [[ $? -ne 0 ]]; then
    help
    exit 1
fi

eval set -- "$OPTS"

while true; do
    case "$1" in
        -f|--fast)
            FAST=true
            shift
            ;;
        -t|--threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        -s|--skip-hashes)
            SKIP_HASHES=true
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

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    help
    exit 1
fi

DEVICE="$1"
OUTPUT="$2"

if ! is_positive_integer "$THRESHOLD"; then
    help
    exit 1
fi

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

if [[ "$SKIP_HASHES" = "false" ]]; then
    echo -n "Creating hashes file ... "

    if ! save_hashes "$MOUNTPOINT" "$OUTPUT_HASHES"; then
        echo "Error: Failed to create the hashes file." >&2
        exit 1
    fi

    echo "OK"
fi

echo -n "Creating compressed file ..."

if ! create_output "$TMP_DIR" "$OUTPUT"; then
    echo "Error: Failed to create the compressed inventory file." >&2
    exit 1
fi

echo "OK"

echo "Created inventory file $OUTPUT"

exit 0
