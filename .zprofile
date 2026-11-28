# ~/.zprofile: read once when you log in on a tty; everything MangoWM starts inherits these
typeset -U path PATH
path=("$HOME/.local/bin" $path /usr/lib/qt6/bin)
export PATH
export EDITOR=nvim VISUAL=nvim
export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent.socket

# Start MangoWM on tty1 after a plain console login (keep this last: exec replaces the shell)
[[ $XDG_SESSION_TYPE == tty && "$(tty)" == "/dev/tty1" ]] && exec mango
