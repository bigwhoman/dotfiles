#!/usr/bin/env bash
# Cycle the external HDMI output: extend -> mirror -> external only -> extend.
# Bound to the F7 display key (XF86Display).
set -uo pipefail

EXT="HDMI-A-1"
INT="eDP-1"
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-hdmi-state"

# `monitors all` also lists outputs Hyprland knows about but has disabled.
present=$(hyprctl -j monitors all | python3 -c "
import json,sys
print('yes' if any(m['name']=='$EXT' for m in json.load(sys.stdin)) else 'no')
")

if [ "$present" != "yes" ]; then
    notify-send -t 2000 "Display" "No HDMI output connected" 2>/dev/null || true
    exit 0
fi

# Mirror first: pressing the display key almost always means "put what I'm
# looking at on the other screen", not "give me a second empty desktop".
case "$(cat "$STATE" 2>/dev/null)" in
    mirror) next=extend ;;
    extend) next=external ;;
    *)      next=mirror ;;
esac

case "$next" in
    extend)
        hyprctl keyword monitor "$INT,2880x1800@60,0x0,2" >/dev/null
        hyprctl keyword monitor "$EXT,preferred,auto,1" >/dev/null
        msg="Extended"
        ;;
    mirror)
        hyprctl keyword monitor "$INT,2880x1800@60,0x0,2" >/dev/null
        hyprctl keyword monitor "$EXT,preferred,auto,1,mirror,$INT" >/dev/null
        msg="Mirrored"
        ;;
    external)
        hyprctl keyword monitor "$EXT,preferred,0x0,1" >/dev/null
        hyprctl keyword monitor "$INT,disable" >/dev/null
        msg="External only"
        ;;
esac

echo "$next" > "$STATE"
notify-send -t 2000 "Display" "$msg" 2>/dev/null || true
