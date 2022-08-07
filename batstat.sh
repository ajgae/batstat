#!/bin/bash

# exit immediately on non-zero exit of pipeline, list or compound
# command, on unset variable, or during a pipeline if one of the
# command files
set -euo pipefail

BATTERY_PATH="/sys/class/power_supply/BAT0"

# prints contents of file $1 found in $BATTERY_PATH
function get_battery_info {
    if [[ -r $BATTERY_PATH/$1 ]]; then
        printf $(< $BATTERY_PATH/$1)
    fi
}

# $1 = string, $2 = type (one of 'ansi' or 'xml'), $3 = color (one of
# 'red', 'green', 'brown' or 'blue')
function format {
    case "$3" in
        red)
            [[ "$2" =~  "ansi" ]] && local COLOR="\e[31m"
            [[ "$2" =~ "xml" ]] && local COLOR="Red"
            ;;
        green)
            [[ "$2" =~ "ansi" ]] && local COLOR="\e[32m"
            [[ "$2" =~ "xml" ]] && local COLOR="Green"
            ;;
        brown)
            [[ "$2" =~ "ansi" ]] && local COLOR="\e[33m"
            [[ "$2" =~ "xml" ]] && local COLOR="Brown"
            ;;
        blue)
            [[ "$2" =~ "ansi" ]] && local COLOR="\e[34m"
            [[ "$2" =~ "xml" ]] && local COLOR="Blue"
            ;;
        *)
            printf "Error: unknown color name '%s' (format), exiting\n" "$3"
            exit 1
            ;;
    esac

    case "$2" in
        ansi)
            printf "${COLOR}${1}\e[0m"
            ;;
        xml)
            printf "<span foreground=\"${COLOR}\">${1}</span>"
            ;;
        *)
            printf "Error: unknown format name '%s' (format), exiting\n" "$2"
            exit 1
            ;;
    esac
}

# get battery info
ENERGY_NOW=$(get_battery_info "energy_now")
ENERGY_FULL=$(get_battery_info "energy_full")
POWER_NOW=$(get_battery_info "power_now")
CHARGE_OR_DISCHARGE=$(get_battery_info "status")

# calculate remaining battery power percentage, and discharge rate in Watts
BAT_PCT=$(bc<<< "scale=2; ${ENERGY_NOW} * 100 / ${ENERGY_FULL}")
BAT_PCT_INT=${BAT_PCT%.*} # keep only integer part (for comparisons)
RATE=$(bc<<< "scale=1; ${POWER_NOW} / 1000000")
RATE_INT=${RATE%.*} # keep only integer part (for comparisons)

if [[ "${BAT_PCT_INT}" -lt "15" ]]; then
    COLOR_PCT="red"
elif [[ "${BAT_PCT_INT}" -lt "30" ]]; then
    COLOR_PCT="brown"  # brown
else
    COLOR_PCT="green" # green
fi

# then for {,dis}charge rate, add colors and sign NOTE: status can be
# one of "Charging", "Discharging" or "Unknown"
#
# FIXME can also be "Full"
if [[ "${CHARGE_OR_DISCHARGE}" == "Charging" ]]; then
    COLOR_RATE="green"
    RATE="+${RATE}" # add plus sign
elif [[ "${CHARGE_OR_DISCHARGE}" == "Discharging" ]]; then
    # add colors depending on how much drain there is on the battery
    if [[ "${RATE_INT}" -lt "7" ]]; then
        COLOR_RATE="green"
    elif [[ "${RATE_INT}" -lt "10" ]]; then
        COLOR_RATE="brown"
    else
        COLOR_RATE="red"
    fi
    RATE="-${RATE}" # add minus sign
else # Unknown
    COLOR_RATE="blue"
    RATE="?${RATE}" # indicate unknown status
fi

# display formatted result
printf "<txt>"
printf "$(format ${BAT_PCT} xml ${COLOR_PCT})%%, "
printf "$(format ${RATE} xml ${COLOR_RATE})W"
printf "</txt>"
