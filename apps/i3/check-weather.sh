#!/bin/bash
#
# Shows current weather information for your location
# Author: z4lthor <z4lthor@gmail.com>
#

DATA=$(fetch-weather)

TEMP=$(jq -r '.temp' <<< "$DATA")
DESC=$(jq -r '.desc' <<< "$DATA")
CODE=$(jq -r '.code' <<< "$DATA")
FEELS_LIKE=$(jq -r '.feelsLike' <<< "$DATA")

case "$CODE" in
    113) ICON="weather-clear" ;;
    116) ICON="weather-few-clouds" ;;
    119|122) ICON="weather-overcast" ;;
    176|263|266|293|296) ICON="weather-showers" ;;
    200|386|389) ICON="weather-storm" ;;
    *) ICON="weather" ;;
esac

dunstify \
    -a Weather \
    -i "$ICON" \
    -u low \
    "🌡 ${TEMP}°C (${FEELS_LIKE}°C)" \
    "$DESC"
