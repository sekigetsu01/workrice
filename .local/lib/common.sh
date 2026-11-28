# shellcheck shell=bash
# What the scripts in ~/.local/bin have in common. A script uses it like this, near the top:
#   APP=books   (its name in notifications, and its window's app id)
#   # shellcheck source-path=SCRIPTDIR source=../lib/common.sh
#   . "$HOME/.local/lib/common.sh"

APP=${APP:-${0##*/}}

export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }--bind=ctrl-h:backward-kill-word --color=16,fg:7,bg:-1,hl:4,fg+:15:bold,bg+:-1,hl+:4:bold:underline,gutter:-1,pointer:4,marker:6,spinner:6,info:8,prompt:4,query:7,header:6,border:8,separator:8,scrollbar:8,label:7,preview-fg:7,preview-bg:-1"

notify() { notify-send --app-name="$APP" "$@" >/dev/null 2>&1 || true; }
die() { printf '%s\n' "$*" >&2; notify --urgency=critical "${APP^}" "$*"; exit 1; }
need() {
    local p
    for p; do command -v "$p" >/dev/null || die "$p isn't installed (sudo pacman -S $p)"; done
}
short() { echo "${1/#$HOME/\~}"; }

step() { printf '\n\e[1m== %s\e[0m\n' "$1"; }
warn() { printf '\e[1;33m%s\e[0m\n' "$1"; }
say() { printf '  %s\n' "$*"; }
# shellcheck disable=SC2034
bad() { printf '\e[1;33m  %s\e[0m\n' "$*"; failed=1; }

term_exec() {
    command -v kitty >/dev/null || die "kitty isn't installed (sudo pacman -S kitty)"
    exec kitty "$@"
}
window() { term_exec --app-id="$APP" --title="$APP" "${WINDOW_OPTS[@]}" -e "${SELF:-$0}" "$@"; }

ipc() {
    [ -S "$SOCK" ] || return 1
    python3 -I - "$SOCK" "$@" <<'EOF'
import json, socket, sys
s = socket.socket(socket.AF_UNIX)
s.settimeout(3)
try:
    s.connect(sys.argv[1])
    s.sendall((json.dumps({"command": sys.argv[2:]}) + "\n").encode())
    buf = b""
    while True:
        c = s.recv(65536)
        if not c:
            sys.exit(1)
        buf += c
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            r = json.loads(line)
            if "event" not in r:
                if r.get("data") is not None:
                    print(r["data"] if isinstance(r["data"], str) else json.dumps(r["data"]))
                sys.exit(0 if r.get("error") == "success" else 1)
except (OSError, ValueError):
    sys.exit(1)
EOF
}

alive() { ipc get_property pid >/dev/null 2>&1; }

FZCOLORS='fg:-1,bg:-1,hl:4,fg+:-1:bold,bg+:-1,hl+:4:bold,gutter:-1,pointer:5,marker:4,prompt:4,query:-1:bold,info:8,header:8,spinner:4,separator:8,scrollbar:8'

fzf_has() { fzf --filter x "$@" </dev/null >/dev/null 2>&1; [ $? != 2 ]; }

# shellcheck disable=SC2034
fzstyle() {
    FZS=(--ansi --layout=reverse --info=hidden --no-scrollbar --no-separator --ellipsis='…'
        --pointer='▌' --marker='▌' --color="$FZCOLORS" --bind 'ctrl-bspace:backward-kill-word')
    fzf_has --gutter=' ' && FZS+=(--gutter=' ')
    PROMPT=(--prompt='› ')
    [ -n "${1:-}" ] && fzf_has --ghost=x && PROMPT=(--prompt='  ' --ghost="$1")
    NI=''
    fzf_has --preview-window=noinfo && NI=',noinfo'
    TABLE=''
    fzf_has --list-border && fzf_has --highlight-line && TABLE=1
}

# shellcheck disable=SC2034
times_load() {
    declare -gA TIMES=()
    local f=${1:-${XDG_CONFIG_HOME:-$HOME/.config}/times.conf} k v
    [ -f "$f" ] || return 0
    while read -r k v || [ -n "$k" ]; do [ -n "$k" ] && TIMES[$k]=$v; done < "$f"
    return 0
}

sudo_keep() {
    sudo -v || return 1
    # (its output away from the script's: else update | tee waits for its sleep to end, up to 50 s after update did)
    ( while kill -0 $$ 2>/dev/null; do sudo -n -v 2>/dev/null; sleep 50; done ) >/dev/null 2>&1 & SUDO_KEEP=$!
    trap 'kill $SUDO_KEEP 2>/dev/null' EXIT
}

pacman_busy() {
    pgrep -x 'pacman|yay|paru|makepkg|pamac' >/dev/null && return 0
    [ -e /var/lib/pacman/db.lck ] && sudo fuser /var/lib/pacman/db.lck >/dev/null 2>&1
}

unlock_pacman() {
    [ -e /var/lib/pacman/db.lck ] || return 0
    command -v fuser >/dev/null || { printf "pacman's lock (/var/lib/pacman/db.lck) is there, and fuser isn't installed to check nothing's using it, so it's left.\n"; return 1; }
    pacman_busy && return 0
    sudo rm -f /var/lib/pacman/db.lck
}
