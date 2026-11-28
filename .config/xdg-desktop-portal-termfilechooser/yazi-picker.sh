#!/bin/sh
# The file picker apps open (to open or save a file): yazi in a kitty window. Saving starts on a placeholder
# file with the suggested name, numbered if one's already there; config next to it runs this
directory=$2 save=$3 path=$4 out=$5
set -e
[ "$6" = 1 ] && set -x

export YAZI_PICKER=1 PATH="$HOME/.local/bin:$PATH"

run_yazi() {
    kitty --title='terminal filechooser' yazi "$@" || true
}

if [ "$save" = 1 ]; then
    name=${path##*/} dir=${path%/*}
    [ -d "$dir" ] || dir="$HOME/Downloads"
    placeholder="$dir/$name"
    if [ -e "$placeholder" ]; then
        base=${name%.*} ext=".${name##*.}"
        if [ "$base" = "$name" ] || [ -z "$base" ]; then base=$name ext=""; fi
        i=1
        while [ -e "$dir/${base}_$i$ext" ]; do i=$((i + 1)); done
        placeholder="$dir/${base}_$i$ext"
    fi
    : > "$placeholder"
    state="$out.state" cwd_file="$out.cwd"
    printf '%s' "$placeholder" > "$state"
    rm -f "$cwd_file"
    export YAZI_SAVE_FILE="$placeholder" YAZI_SAVE_STATE="$state" YAZI_SAVE_NAME="$dir/$name"
    run_yazi --chooser-file="$out" --cwd-file="$cwd_file" "$placeholder"
    unset YAZI_SAVE_FILE YAZI_SAVE_STATE YAZI_SAVE_NAME

    current=$placeholder picked=
    { IFS= read -r current || :; } 2>/dev/null < "$state" || :
    { IFS= read -r picked || :; } 2>/dev/null < "$out" || :
    target=""
    if [ -d "$picked" ]; then
        target="$current"
    elif [ -n "$picked" ]; then
        target="$picked"
    elif [ -s "$cwd_file" ]; then
        target="$current"
    fi
    if [ "$target" = "$current" ] && [ ! -e "$current" ]; then target=""; fi
    rm -f "$state" "$cwd_file"
    if [ "$target" != "$current" ] && [ -f "$current" ] && [ ! -s "$current" ]; then
        rm -f -- "$current"
    fi
    if [ -n "$target" ]; then
        printf '%s\n' "$target" > "$out"
        last="${XDG_STATE_HOME:-$HOME/.local/state}/yazi/last-save-dir"
        mkdir -p "${last%/*}" && printf '%s\n' "${target%/*}" > "$last"
    else
        : > "$out"
    fi
elif [ "$directory" = 1 ]; then
    run_yazi --chooser-file="$out" --cwd-file="$out.1" "$path"
    if [ ! -s "$out" ] && [ -s "$out.1" ]; then cat "$out.1" > "$out"; fi
    rm -f "$out.1"
else
    run_yazi --chooser-file="$out" "$path"
fi
