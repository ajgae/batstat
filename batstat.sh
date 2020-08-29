#!/bin/bash

BATTERY_PATH="/sys/class/power_supply/BAT0"

# echoes content of file $1 found in $BATTERY_PATH
get_battery_info() {
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
# we get values that are valid for bash arithmetic
if (( ${battery_percent%.*} < 15 )); then
    color_pct="\e[31m"  # red
elif (( ${battery_percent%.*} < 50 )); then
    color_pct="\e[33m"  # brown
fi

# then for discharge rate, add colors + sign
color_rate="\e[0m"
# NOTE : status can be one of Charging, Discharging or Unknown
if [[ $ac_status == "Charging" ]]; then
    discharge_rate="+$discharge_rate"
    color_rate="\e[32m" # green
elif [[ $ac_status == "Discharging" ]]; then
    discharge_rate="-$discharge_rate"
    color_rate="\e[31m" # red
else
    discharge_rate="?$discharge_rate"
    color_rate="\e[33m" # brown
fi

# display formatted result
echo -e "Battery : ${color_pct}${battery_percent}${color_clear}%, ${color_rate}${discharge_rate}${color_clear}W"
