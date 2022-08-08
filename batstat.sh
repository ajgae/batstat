#!/bin/bash

# exit immediately on non-zero exit of pipeline, list or compound
# command, on unset variable, or during a pipeline if one of the
# command files
set -euo pipefail

function die_usage {
    printf "Usage: batstat [-nbw] [-f FORMAT]
  -n               Do not append a newline to the output
                   (which is the default behavior)
  -b               Print battery percentage only (incompatible
                   with -w)
  -w               Print wattage only (incompatible with -b)
  -f FORMAT        Use the specified output format for colors.
                   FORMAT must be one of 'ansi' or 'xfce-genmon'
                   (default: 'ansi'). 'xfce-genmon' is intended
                   for use with the Xfce4 panel general monitor
                   plugin (see https://docs.xfce.org/panel-plugins/xfce4-genmon-plugin/)
"
    exit 2
}

# prints contents of file $1 found in directory $2
function get_battery_info {
    if [[ -r $2/$1 ]]; then
        printf $(< $2/$1)
    fi
}

# $1 = string, $2 = color (one of 'red', 'green', 'brown' or 'blue')
function format {
    local COLOR
    case "$2" in
        red)
            [[ "${OPT_FORMAT}" =~  "ansi" ]] && COLOR="\e[31m"
            [[ "${OPT_FORMAT}" =~ "xfce-genmon" ]] && COLOR="Red"
            ;;
        green)
            [[ "${OPT_FORMAT}" =~ "ansi" ]] && COLOR="\e[32m"
            [[ "${OPT_FORMAT}" =~ "xfce-genmon" ]] && COLOR="Green"
            ;;
        brown)
            [[ "${OPT_FORMAT}" =~ "ansi" ]] && COLOR="\e[33m"
            [[ "${OPT_FORMAT}" =~ "xfce-genmon" ]] && COLOR="Brown"
            ;;
        blue)
            [[ "${OPT_FORMAT}" =~ "ansi" ]] && COLOR="\e[34m"
            [[ "${OPT_FORMAT}" =~ "xfce-genmon" ]] && COLOR="Blue"
            ;;
        *)
            printf "Internal error (format): unknown color name '%s', exiting\n" "$2"
            exit 1
            ;;
    esac

    case "${OPT_FORMAT}" in
        ansi)
            printf "${COLOR}${1}\e[0m"
            ;;
        xfce-genmon)
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
OPT_BAT_ONLY="false"
OPT_WATT_ONLY="false"
while getopts ":nf:wb" CUR_OPT; [[ "$?" == "0" ]]; do
    if [[ "${CUR_OPT}" == "?" ]]; then
        # illegal option
        die_usage
    fi
    # for debugging
    #printf "${CUR_OPT}: ${OPTARG:-<nothing>}\n"
    case ${CUR_OPT} in
        n)
            OPT_NO_NEWLINE="true"
            ;;
        w)
            [[ "${OPT_BAT_ONLY}" == "false" ]] || die_usage
            OPT_WATT_ONLY="true"
            ;;
        b)
            [[ "${OPT_WATT_ONLY}" == "false" ]] || die_usage
            OPT_BAT_ONLY="true"
            ;;
        f)
            case ${OPTARG} in
                ansi)
                    OPT_FORMAT="ansi"
                    ;;
                xfce-genmon)
                    OPT_FORMAT="xfce-genmon"
                    ;;
                *)
                    die_usage
                    ;;
            esac
            ;;
        # no need for *) case because illegal options are checked
        # above
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
elif [[ "${CHARGE_OR_DISCHARGE}" == "Full" ]]; then
    COLOR_RATE="green"
else # Unknown
    COLOR_RATE="blue"
    RATE="?${RATE}" # indicate unknown status
fi

# display formatted result
[[ "${OPT_FORMAT}" == "xfce-genmon" ]] && printf "<txt>"
[[ "${OPT_WATT_ONLY}" == "false" ]] && printf "$(format ${BAT_PCT} ${COLOR_PCT})%%"
if [[ "${OPT_BAT_ONLY}" == "false" ]] && [[ "${OPT_WATT_ONLY}" == "false" ]]; then
    printf ", "
fi
[[ "${OPT_BAT_ONLY}" == "false" ]] && printf "$(format ${RATE} ${COLOR_RATE})W"
[[ "${OPT_FORMAT}" == "xfce-genmon" ]] && printf "</txt>"
[[ "${OPT_NO_NEWLINE}" == "false" ]] && printf "\n"
