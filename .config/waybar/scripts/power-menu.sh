#!/usr/bin/env bash

# Power menu for the Waybar power button.
# Uses wofi (the launcher this setup ships with); falls back to rofi if present.

set -uo pipefail

# wofi loads the stylesheet as raw data, so relative @import paths do not
# resolve. Expand $HOME into a runtime copy instead of hardcoding a path.
style_src="$HOME/.config/wofi/power-menu.css"
style="${XDG_RUNTIME_DIR:-/tmp}/wofi-power-menu.css"
sed "s|\$HOME|$HOME|g" "$style_src" >"$style" 2>/dev/null || style="$style_src"

# Second click on the button dismisses an open menu.
if pkill -x wofi; then
  exit 0
fi

lock=$'  Lock'
shutdown=$'  Shutdown'
reboot=$'  Reboot'
suspend=$'  Suspend'
hibernate=$'  Hibernate'
logout=$'  Logout'

actions="$lock
$shutdown
$reboot
$suspend
$hibernate
$logout"

if command -v wofi >/dev/null 2>&1; then
  selected_option=$(printf '%s\n' "$actions" | wofi \
    --dmenu \
    --style "$style" \
    --hide-search \
    --hide-scroll \
    --no-actions \
    --cache-file /dev/null \
    --location top_right \
    --width 170 \
    --lines 6 \
    --xoffset -6 \
    --yoffset 6) || exit 0
elif command -v rofi >/dev/null 2>&1; then
  selected_option=$(printf '%s\n' "$actions" |
    rofi -dmenu -i -config "$HOME/.config/rofi/power-menu.rasi") || exit 0
else
  notify-send "Power menu" "Neither wofi nor rofi is installed." 2>/dev/null
  exit 1
fi

do_lock() {
  if command -v hyprlock >/dev/null 2>&1; then
    hyprlock
  elif command -v swaylock >/dev/null 2>&1; then
    swaylock -f
  else
    loginctl lock-session
  fi
}

do_logout() {
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch exit
  elif [[ -n ${XDG_SESSION_ID:-} ]]; then
    loginctl terminate-session "$XDG_SESSION_ID"
  else
    loginctl terminate-user "$USER"
  fi
}

case "$selected_option" in
*Lock) do_lock ;;
*Shutdown) systemctl poweroff ;;
*Reboot) systemctl reboot ;;
*Suspend) do_lock & sleep 0.5; systemctl suspend ;;
*Hibernate) do_lock & sleep 0.5; systemctl hibernate ;;
*Logout) do_logout ;;
esac
