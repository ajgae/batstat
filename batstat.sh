#!/bin/bash

BATTERY_PATH="/sys/class/power_supply/BAT0"

# echoes content of file $1 found in $BATTERY_PATH
function get_battery_info {
    if [[ -r $BATTERY_PATH/$1 ]]; then
        printf $(< $BATTERY_PATH/$1)
    fi
}

# returns $1 wrapped between $2 and "\e[0m" (clear color)
function add_color {
    printf "${2}${1}\e[0m"
}

# get battery info
energy_now=$(get_battery_info "energy_now")
energy_full=$(get_battery_info "energy_full")
power_now=$(get_battery_info "power_now")
ac_status=$(get_battery_info "status")

# calculate remaining battery power percentage, and discharge rate in Watts
bat_pct=$(bc<<< "scale=2; ${energy_now} * 100 / ${energy_full}")
bat_pct_int=${bat_pct%.*} # keep only integer part (for comparisons)
rate=$(bc<<< "scale=1; ${power_now} / 1000000")
rate_int=${rate%.*} # keep only integer part (for comparisons)

if [[ "${bat_pct_int}" -lt "15" ]]; then
    color_pct="\e[31m"  # red
elif [[ "${bat_pct_int}" -lt "30" ]]; then
    color_pct="\e[33m"  # brown
else
    color_pct="\e[32m" # green
fi

# then for {,dis}charge rate, add colors + sign
# NOTE: status can be one of "Charging", "Discharging" or "Unknown"
if [[ "${ac_status}" == "Charging" ]]; then
    color_rate="\e[32m" # green
    rate="+${rate}" # add plus sign
elif [[ "${ac_status}" == "Discharging" ]]; then
    # add colors depending on how much drain there is on the battery
    if [[ "${rate_int}" -lt "5" ]]; then
        color_rate="\e[32m" # green
    elif [[ "${rate_int}" -lt "10" ]]; then
        color_rate="\e[33m" # brown
    else
        color_rate="\e[31m" # red
    fi
    rate="-${rate}" # add minus sign
else # Unknown
    color_rate="\e[34m" # blue
    rate="?${rate}" # indicate unknown status
fi

# display formatted result
echo -e "Battery : $(add_color ${bat_pct} ${color_pct})%, $(add_color ${rate} ${color_rate})W"
