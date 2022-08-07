#!/bin/bash
set -euo pipefail

# Options:
# -n: don't append newline to output
# -f: format type (default 'ansi', one of 'xml' or 'ansi')

# exit immediately on non-zero exit of pipeline, list or compound
# command, on unset variable, or during a pipeline if one of the
# command files

function usage {
    printf "hello
world\n"
}

# prints contents of file $1 found in directory $2
function get_battery_info {
    if [[ -r $2/$1 ]]; then
        printf $(< $2/$1)
    fi
}

# $1 = string, $2 = color (one of
# 'red', 'green', 'brown' or 'blue')
function format {
    case "$2" in
        red)
            [[ "${OPT_FORMAT}" =~  "ansi" ]] && local COLOR="\e[31m"
            [[ "${OPT_FORMAT}" =~ "xml" ]] && local COLOR="Red"
            ;;
        green)
            [[ "${OPT_FORMAT}" =~ "ansi" ]] && local COLOR="\e[32m"
            [[ "${OPT_FORMAT}" =~ "xml" ]] && local COLOR="Green"
            ;;
        brown)
            [[ "${OPT_FORMAT}" =~ "ansi" ]] && local COLOR="\e[33m"
            [[ "${OPT_FORMAT}" =~ "xml" ]] && local COLOR="Brown"
            ;;
        blue)
            [[ "${OPT_FORMAT}" =~ "ansi" ]] && local COLOR="\e[34m"
            [[ "${OPT_FORMAT}" =~ "xml" ]] && local COLOR="Blue"
            ;;
        *)
            printf "Internal error (format): unknown color name '%s', exiting\n" "$2"
            # don't print usage, colors are internal to the script and
            # not yet customizable
            exit 1
            ;;
    esac

    case "${OPT_FORMAT}" in
        ansi)
            printf "${COLOR}${1}\e[0m"
            ;;
        xml)
            printf "<span foreground=\"${COLOR}\">${1}</span>"
            ;;
        *)
            printf "Internal error (format): unkwown format type '%s', exiting\n" "${OPT_FORMAT}"
            exit 1
            ;;
    esac
}

# process positional parameters
OPT_NO_NEWLINE="false"
OPT_FORMAT="ansi"
while getopts ":nf:" CUR_OPT; [[ "$?" == "0" ]]; do
    if [[ "${CUR_OPT}" == "?" ]]; then
        printf "illegal option: ${CUR_OPT}, exiting\n"
        usage
        exit 1
    fi
    printf "${CUR_OPT}: ${OPTARG:-<nothing>}\n"
    case ${CUR_OPT} in
        n)
            OPT_NO_NEWLINE="true"
            ;;
        f)
            case ${OPTARG} in
                ansi)
                    OPT_FORMAT="ansi"
                    ;;
                xml)
                    OPT_FORMAT="xml"
                    ;;
                *)
                    printf "unknown format type: ${OPTARG}, exiting\n"
                    usage
                    exit 1
                    ;;
            esac
            ;;
    esac
done

BATTERY_PATH="/sys/class/power_supply/BAT0"

# get battery info
ENERGY_NOW=$(get_battery_info "energy_now" ${BATTERY_PATH})
ENERGY_FULL=$(get_battery_info "energy_full" ${BATTERY_PATH})
POWER_NOW=$(get_battery_info "power_now" ${BATTERY_PATH})
CHARGE_OR_DISCHARGE=$(get_battery_info "status" ${BATTERY_PATH})

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
[[ "${OPT_FORMAT}" == "xml" ]] && printf "<txt>"
printf "$(format ${BAT_PCT} ${COLOR_PCT})%%, "
printf "$(format ${RATE} ${COLOR_RATE})W"
[[ "${OPT_FORMAT}" == "xml" ]] && printf "</txt>"
[[ "${OPT_NO_NEWLINE}" == "false" ]] && printf "\n"
