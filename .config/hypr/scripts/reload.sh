#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/.config/wallpapers/"
STATE_FILE="/tmp/hyprpaper_current"

# 1. Check our custom state file to see what the current wallpaper is
if [ -f "$STATE_FILE" ]; then
    CURRENT_WALL=$(cat "$STATE_FILE")
    # Find a random wallpaper excluding the current one
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f ! -name "$(basename "$CURRENT_WALL")" | shuf -n 1)
else
    # If no state file exists, just grab any random wallpaper
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f | shuf -n 1)
fi

# 2. Failsafe: Check if a wallpaper was actually found
if [ -z "$WALLPAPER" ]; then
    echo "Error: No new wallpaper found in $WALLPAPER_DIR"
    exit 1
fi

# 3. Apply the wallpaper using the NEW IPC syntax
# (The comma with nothing before it applies it to all monitors)
hyprctl hyprpaper wallpaper ", $WALLPAPER"

# 4. Save the new wallpaper to the state file so we don't repeat it next time
echo "$WALLPAPER" > "$STATE_FILE"
