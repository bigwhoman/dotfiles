#!/usr/bin/env bash
# Toggle the internal panel between 60 Hz (battery) and 120 Hz (plugged in).
# 120 Hz costs roughly 0.5-1.0 W on this 2880x1800 OLED.
set -uo pipefail

MON="eDP-1"
MODE="2880x1800"
SCALE=2

cur=$(hyprctl -j monitors | python3 -c "
import json,sys
print(next((round(m['refreshRate']) for m in json.load(sys.stdin) if m['name']=='$MON'), 0))
")

if [ "${cur:-0}" -ge 100 ]; then new=60; else new=120; fi

hyprctl keyword monitor "$MON,${MODE}@${new},0x0,$SCALE" >/dev/null
notify-send -t 2000 "Display" "${new} Hz" 2>/dev/null || true
