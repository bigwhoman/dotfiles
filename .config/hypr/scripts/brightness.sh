#!/usr/bin/env bash
# Adjust internal panel backlight. Usage: brightness.sh +10 | brightness.sh -10
# Uses brightnessctl when available, otherwise writes /sys directly (needs
# membership in the `video` group, which Arch's udev rules make writable).
set -uo pipefail

STEP="${1:-+10}"

if command -v brightnessctl >/dev/null 2>&1; then
    case "$STEP" in
        -*) brightnessctl -q set "${STEP#-}%-" ;;
        *)  brightnessctl -q set "${STEP#+}%+" ;;
    esac
    cur=$(brightnessctl g); max=$(brightnessctl m)
else
    dev=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1)
    [ -n "$dev" ] || exit 1
    max=$(< "$dev/max_brightness")
    cur=$(< "$dev/brightness")
    delta=$(( max * ${STEP#[+-]} / 100 ))
    case "$STEP" in
        -*) new=$(( cur - delta )) ;;
        *)  new=$(( cur + delta )) ;;
    esac
    # Floor at 1% rather than 0 so the screen never goes fully black.
    min=$(( max / 100 )); [ "$min" -lt 1 ] && min=1
    [ "$new" -lt "$min" ] && new=$min
    [ "$new" -gt "$max" ] && new=$max
    echo "$new" > "$dev/brightness" || exit 1
    cur=$new
fi

pct=$(( cur * 100 / max ))
notify-send -t 1000 -h string:x-canonical-private-synchronous:brightness \
    -h int:value:"$pct" "Brightness" "${pct}%" 2>/dev/null || true
