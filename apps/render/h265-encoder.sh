#!/bin/bash

BIN=ffmpeg
INPUT=$1
OUTPUT=$2
VCODEC=libx265
CRF=25
PRESET="medium"
ACODEC=aac
ABITRATE=128k

if ! command -v $BIN > /dev/null 2>&1; then
    echo "Not Found $BIN"
    exit 1
fi

$BIN -loglevel quiet -i $INPUT -c:v $VCODEC -c:a $ACODEC -crf $CRF -preset $PRESET -b:a $ABITRATE -tag:v hvc1 $OUTPUT

exit 0
