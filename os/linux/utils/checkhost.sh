#!/bin/bash
#
# Check host connectivity
# Author: z4lthor <z4lthor@gmail.com>
#

RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
CYAN="\e[96m"
RESET="\e[0m"

help() {
cat <<EOF
Usage:
$0 [options] <HOST>

Options:
-h, --help                Show this help
EOF
}

error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

info() {
    if [[ "$2" == "ONLINE" ]]; then
        RES="${GREEN}$2${RESET}"
    else
        RES="${RED}$2${RESET}"
    fi

    echo -e "${CYAN}[INFO]${RESET} Host ${BLUE}$1${RESET} is $RES"
}

OPTS=$(getopt -o c:p:h \
    --long crf:,preset:,audio-bitrate:,help \
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

HOST="$1"

if [[ $# -ne 1 ]]; then
    error "Mandatory HOST"
    help
    exit 1
fi

if ping -c1 -W1 "$HOST" > /dev/null 2>&1; then
    info $HOST "ONLINE"
else
    info $HOST "DOWN"
    exit 1
fi

exit 0
