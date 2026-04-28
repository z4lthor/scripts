#!/bin/bash
#
# Unmount and close a LUKS volume
# Author: z4lthor <z4lthor@gmail.com>
#

BIN=/usr/bin/cryptsetup

RED="\e[31m"
GREEN="\e[32m"
RESET="\e[0m"

help() {
    echo -e "Usage: $(basename "$0") MOUNTPOINT"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

info() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}

if [[ $EUID -ne 0 ]]; then
    error "Must be root"
    exit 1
fi

if ! command -v $BIN > /dev/null 2>&1; then
    error "$BIN not found"
    exit 1
fi

MOUNTPOINT="${1%/}"

if [[ -z "$MOUNTPOINT" ]]; then
    help
    exit 1
fi

if ! mountpoint -q "$MOUNTPOINT"; then
    error "$MOUNTPOINT is not an active mount point."
    exit 1
fi

DEVICE=$(findmnt -n -o SOURCE "$MOUNTPOINT")

if [[ -z "$DEVICE" ]]; then
    error "Could not determine the device associated with $MOUNTPOINT"
    exit 1
fi

if umount "$MOUNTPOINT"; then
    info "Mount point $MOUNTPOINT unmounted successfully."
else
    error "Failed to unmount $MOUNTPOINT. Check if files are still in use."
    exit 1
fi

if [[ "$DEVICE" == /dev/mapper/* ]]; then
    NAME=$(basename "$DEVICE")
    if $BIN luksClose "$NAME"; then
        info "LUKS container [$NAME] closed successfully."
    else
        error "Failed to close LUKS container $NAME."
        exit 1
    fi
else
    info "Device $DEVICE is not a LUKS mapped volume. Skipping luksClose."
fi

exit 0
