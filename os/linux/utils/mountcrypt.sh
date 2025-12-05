#!/bin/bash

BIN=/usr/bin/cryptsetup
DEVICE=$1
MOUNT=$2

if [[ $EUID -ne 0 ]]; then
    echo "Error: You must be root"
    exit 1
fi

if ! command -v $BIN > /dev/null 2>&1; then
    echo "$BIN not found"
    exit 1
fi

if [[ ! -b "$DEVICE" ]]; then
    echo "Error: $DEVICE is not a block device"
    exit 1
fi

if [[ ! -d "$MOUNT" ]]; then
    echo "Error: $MOUNT is not a directory"
    exit 1
fi

if ! $BIN isLuks "$DEVICE"; then
    echo "Error: $DEVICE is not a LUKS device"
    exit 1
fi

NAME="$(basename "$DEVICE")_crypt"

$BIN luksOpen $DEVICE $NAME
mount /dev/mapper/$NAME $MOUNT

exit 0
