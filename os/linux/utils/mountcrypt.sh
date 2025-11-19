#!/bin/bash

DEVICE=$1
NAME=$2
MOUNT=$3

cryptsetup luksOpen $DEVICE $NAME
mount /dev/mapper/$NAME $MOUNT

exit 0
