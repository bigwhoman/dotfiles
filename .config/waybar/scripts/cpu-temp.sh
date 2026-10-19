#!/usr/bin/env bash

model=$(awk -F ': ' '/model name/{print $2}' /proc/cpuinfo | head -n 1 | sed 's/@.*//; s/ *\((R)\|(TM)\)//g; s/^[ \t]*//; s/[ \t]*$//')

# Get CPU clock speeds
get_cpu_frequency() {
  freqlist=$(awk '/cpu MHz/ {print $4}' /proc/cpuinfo)
  maxfreq=$(sed 's/...$//' /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
  average_freq=$(echo "$freqlist" | tr ' ' '\n' | awk "{sum+=\$1} END {printf \"%.0f/%s MHz\", sum/NR, $maxfreq}")
  echo "$average_freq"
}

# Get CPU temperature.
# Reads the x86_pkg_temp thermal zone straight from sysfs - no fork at all.
# Falls back to `sensors` (2 forks, walks every hwmon device) only if that is missing.
_pkg_temp_zone=""
for _z in /sys/class/thermal/thermal_zone*; do
  if [[ -r "$_z/type" && "$(<"$_z/type")" == "x86_pkg_temp" ]]; then
    _pkg_temp_zone="$_z/temp"
    break
  fi
done

get_cpu_temperature() {
  local temp="" temp_f=""
  if [[ -n "$_pkg_temp_zone" && -r "$_pkg_temp_zone" ]]; then
    temp=$(( $(<"$_pkg_temp_zone") / 1000 ))
  else
    local sensors_out
    sensors_out=$(sensors)
    temp=$(awk '/Package id 0/ {print $4}' <<<"$sensors_out" | awk -F '[+.]' '{print $2}')
    [[ -z "$temp" ]] && temp=$(awk '/Tctl/ {print $2}' <<<"$sensors_out" | tr -d '+\u00b0C')
  fi
  if [[ -z "$temp" ]]; then
    temp="N/A"
  else
    temp_f=$(awk "BEGIN {printf \"%.1f\", ($temp * 9 / 5) + 32}")
  fi
  echo "${temp:-N/A} ${temp_f:-N/A}"
}

# Get the corresponding icon based on temperature
get_temperature_icon() {
  temp_value=$1
  if [ "$temp_value" -ge 80 ]; then
    icon="󰸁" # High temperature
  elif [ "$temp_value" -ge 70 ]; then
    icon="󱃂" # Medium temperature
  elif [ "$temp_value" -ge 60 ]; then
    icon="󰔏" # Normal temperature
  else
    icon="󱃃" # Low temperature
  fi
  echo "$icon"
}

# Main script execution
cpu_frequency=$(get_cpu_frequency)
read -r temp_info < <(get_cpu_temperature)
temp=$(echo "$temp_info" | awk '{print $1}')   # Celsius
temp_f=$(echo "$temp_info" | awk '{print $2}') # Fahrenheit

# Determine the temperature icon
thermo_icon=$(get_temperature_icon "$temp")

# Set color based on temperature
if [ "$temp" -ge 80 ]; then
  # If temperature is >= 80%, set color to #f38ba8
  text_output="<span color='#f38ba8'>${thermo_icon} ${temp}°C</span>"
else
  # Default color
  text_output="${thermo_icon} ${temp}°C"
fi

tooltip=":: ${model}\n"
tooltip+="Clock Speed: ${cpu_frequency}\nTemperature: ${temp_f}°F"

# Module and tooltip
echo "{\"text\": \"$text_output\", \"tooltip\": \"$tooltip\"}"
