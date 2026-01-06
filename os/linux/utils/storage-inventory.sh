#!/bin/bash
#
# Creates a detailed inventory of a storage device
# Author: z4lthor <z4lthor@gmail.com>
#

if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 PATH OUTPUT"
    exit 1
fi

SRCPATH=$(realpath -m "$1")
DSTFILE=$(realpath -m "$2")

if [[ ! -d "$SRCPATH" ]];then
    echo "Source path is invalid: $SRCPATH"
    exit 1
fi

find $SRCPATH -printf "%M %u %g %s %t %p\n" > $DSTFILE

exit 0
