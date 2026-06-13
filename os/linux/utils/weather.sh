#!/bin/bash
#
# Fetches current weather information for your location
# Author: z4lthor <z4lthor@gmail.com>
#

DATA=$(curl -s 'https://wttr.in/?format=j1')

if [[ -z "$DATA" ]]; then
    echo "Error: URL not respond"
    exit 1
fi

jq -c '{
    temp: .current_condition[0].temp_C,
    desc: .current_condition[0].weatherDesc[0].value,
}' <<< "$DATA"
