#!/bin/bash
#
# Open and mount a LUKS volume
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/cryptsetup
MAPPING_SUFFIX="crypt"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

help() {
cat <<EOF
Usage:
$0 [options] <DEVICE> <MOUNT_POINT>

Options:
-h, --help                Show this help
EOF
}

error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

info() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

if [[ $EUID -ne 0 ]]; then
    error "Error: You must be root"
    exit 1
fi

if ! command -v $BIN > /dev/null 2>&1; then
    error "$BIN not found"
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

if [[ $# -ne 2 ]]; then
    error "Mandatory DEVICE and MOUNT_POINT"
    help
    exit 1
fi

DEVICE="$1"
MOUNT="$2"

if [[ ! -b "$DEVICE" ]]; then
    error "$DEVICE is not a block device"
    exit 1
fi

if [[ ! -d "$MOUNT" ]]; then
    error "$MOUNT is not a directory"
    exit 1
fi

if ! $BIN isLuks "$DEVICE"; then
    error "$DEVICE is not a LUKS device"
    exit 1
fi

NAME="$(basename "$DEVICE")_$MAPPING_SUFFIX"

if [[ -e /dev/mapper/$NAME ]]; then
    error "Device $DEVICE is already opened"
    exit 1
fi

$BIN luksOpen $DEVICE $NAME

if [[ $? -eq 0 ]]; then
    info "LUKS $DEVICE opened on /dev/mapper/$NAME"
else
    error "Cannot open LUKS"
    exit 1
fi

mount /dev/mapper/$NAME $MOUNT

if [[ $? -eq 0 ]]; then
    info "LUKS /dev/mapper/$NAME mounted on $MOUNT"
else
    error "Cannot mount LUKS"
    $BIN luksClose $NAME
    exit 1
fi

exit 0
