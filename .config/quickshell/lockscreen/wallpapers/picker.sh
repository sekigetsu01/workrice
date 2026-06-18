#!/bin/bash
LS="$(dirname "$(realpath "$0")")"

WALLPAPER=$(ls "$LS"/*.jpg "$LS"/*.png "$LS"/*.jpeg 2>/dev/null | shuf -n 1)

# debug — check if this file exists
echo "DEBUG: $WALLPAPER" >&2

FILENAME=$(basename "$WALLPAPER")

awk -v file="$FILENAME" -v wallpaper="$WALLPAPER" '
BEGIN {
    themes["gojo.jpg"]   = "#4B0082|#7675C4|-75"
    themes["berserk.png"] = "#CE0112|#C73636|-75"

    clock  = "#4B0082"
    locked = "#7675C4"
    offset = "-75"

    if (file in themes) {
        split(themes[file], t, "|")
        clock  = t[1]
        locked = t[2]
        offset = t[3]
    }

    print wallpaper "|" clock "|" locked "|" offset
}' /dev/null
