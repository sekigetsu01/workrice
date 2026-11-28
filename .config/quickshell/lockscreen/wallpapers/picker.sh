#!/bin/sh
# The lock screen's wallpaper: a random picture from this folder, with the colours that go with it (LockContext.qml)
dir=$(dirname "$(realpath "$0")")
wp=$(find "$dir" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) | shuf -n 1)
case ${wp##*/} in
    berserk.png) theme="#CE0112|#C73636|-75" ;;
    *)           theme="#4B0082|#7675C4|-75" ;;
esac
echo "$wp|$theme"
