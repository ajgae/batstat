#!/bin/bash

BATTERY_PATH="/sys/class/power_supply/BAT0"

# echoes content of file $1 found in $BATTERY_PATH
function get_battery_info {
    if [[ -r $BATTERY_PATH/$1 ]]; then
        echo $(< $BATTERY_PATH/$1)
    fi
}

# get battery info
energy_now=$(get_battery_info "energy_now")
energy_full=$(get_battery_info "energy_full")
power_now=$(get_battery_info "power_now")
ac_status=$(get_battery_info "status")

# calculate remaining battery power percentage, and discharge rate in Watts
battery_percent=$(bc<<< "scale=2; $energy_now * 100 / $energy_full")
discharge_rate=$(bc<<< "scale=1; $power_now / 1000000")

# set cool colors
color_clear="\e[0m"

# first for battery percentage
color_pct="\e[32m"      # green
# %.* means remove suffix of the form .*, so that
# we get integer values that are valid for bash arithmetic
if [[ ${battery_percent%.*} -lt "15" ]]; then
    color_pct="\e[31m"  # red
elif [[ ${battery_percent%.*} -lt "30" ]]; then
    color_pct="\e[33m"  # brown
fi

# then for {,dis}charge rate, add colors + sign
# NOTE : status can be one of Charging, Discharging or Unknown
if [[ $ac_status == "Charging" ]]; then
    color_rate="\e[32m" # green
    discharge_rate="+${discharge_rate}"
elif [[ "$ac_status" == "Discharging" ]]; then
    discharge_rate_int="${discharge_rate%.*}"
    echo "Discharge rate (int): ${discharge_rate_int}"
    # add colors depending on how much drain there is on the battery
    if [[ "$discharge_rate_int" -lt "5" ]]; then
        color_rate="\e[32m" # green
    elif [[ "$discharge_rate_int" -lt "10" ]] && [[ "$discharge_rate_int" >=5 ]]; then
        color_rate="\e[33m" # brown
    else
        color_rate="\e[31m" # red
    fi
    discharge_rate="-$discharge_rate"
else # Unknown
    color_rate="\e[34m" # blue
    discharge_rate="?$discharge_rate"
fi

# display formatted result
echo -e "Battery : ${color_pct}${battery_percent}${color_clear}%, ${color_rate}${discharge_rate}${color_clear}W"
