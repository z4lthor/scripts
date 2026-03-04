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

print_msg() {
    local msg="$1"
    local status="$2"

    if [[ "$status" == "ONLINE" ]]; then
        RES="${GREEN}$status${RESET}"
    else
        RES="${RED}$status${RESET}"
    fi

    echo -e "Host ${BLUE}$msg${RESET} is $RES"
}

HOST="$1"

if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") HOST"
    exit 1
fi

if ping -c1 -W1 "$HOST" > /dev/null 2>&1; then
    print_msg $HOST "ONLINE"
else
    print_msg $HOST "DOWN"
    exit 1
fi

exit 0
