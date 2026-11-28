# zsh: the interactive shell (prompt, history, vi keys, completion, yazi/fzf keys, zoxide, plugins);
# aliases and functions are in ~/.config/shell/aliasrc
autoload -Uz add-zsh-hook
PROMPT=$'%B%F{cyan}╔%F{red}[%F{yellow}%n%F{green}@%F{blue}%m %F{magenta}%~%F{red}]%f\n%F{cyan}╚>%f%b '
setopt autocd interactive_comments auto_pushd pushd_ignore_dups pushd_silent no_beep no_flow_control
DIRSTACKSIZE=20

HISTSIZE=10000000
SAVEHIST=10000000
HISTFILE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/history"
[[ -d ${HISTFILE:h} ]] || mkdir -p "${HISTFILE:h}"
setopt share_history extended_history hist_ignore_all_dups hist_reduce_blanks hist_ignore_space
zshaddhistory() {
    local cmd=${1%%$'\n'}
    (( ${#cmd} <= 300 )) && [[ $cmd != *$'\n'*$'\n'*$'\n'* ]]
}

bindkey -v
export KEYTIMEOUT=1

_zcache() {
    local f=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/$1.zsh bin=${commands[$2]}
    [[ -n $bin ]] || return 1
    [[ -s $f && $f -nt $bin ]] || "${@:2}" > $f 2>/dev/null || { command rm -f $f; return 1; }
    source $f
}

[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/shell/aliasrc" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/shell/aliasrc"

autoload -U compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-z}=A-Z' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zmodload zsh/complist
_zcd="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION"
_zcd_stale=( $_zcd(N.mh+24) )
if [[ ! -f $_zcd ]] || (( ${#_zcd_stale} )); then
    compinit -d "$_zcd" && touch "$_zcd"
else
    compinit -C -d "$_zcd"
fi
[[ $_zcd.zwc -nt $_zcd ]] || zcompile -R -- "$_zcd"
unset _zcd _zcd_stale
# gcl <Tab>: your GitHub repos
_gcl() {
    local c=${XDG_CACHE_HOME:-$HOME/.cache}/gcl-repos u=$(_gcl_user)
    if [[ -n $u ]] && { [[ ! -s $c ]] || (( $(date +%s) - $(stat -c %Y -- $c) > 86400 )); }; then
        command mkdir -p -- ${c:h}
        curl -fsS --max-time 5 "https://api.github.com/users/$u/repos?per_page=100" 2>/dev/null | jq -r '.[].name' > $c.tmp 2>/dev/null &&
            [[ -s $c.tmp ]] && command mv -f -- $c.tmp $c || command rm -f -- $c.tmp
    fi
    local -a typed=(${words[2,CURRENT-1]})
    [[ -n ${(M)typed:#-*} ]] && return
    [[ -r $c ]] && compadd -F typed -- ${(f)"$(<$c)"}
}
compdef _gcl gcl
_comp_options+=(globdots)

bindkey -M menuselect h vi-backward-char k vi-up-line-or-history l vi-forward-char j vi-down-line-or-history
# Shift+Enter is Enter
bindkey -M viins '^[[27;2;13~' accept-line
bindkey -M vicmd '^[[27;2;13~' accept-line

autoload -Uz select-bracketed select-quoted
zle -N select-bracketed
zle -N select-quoted
for m in visual viopp; do
    for c in {a,i}${(s..)^:-'()[]{}<>bB'}; do
        bindkey -M $m $c select-bracketed
    done
    for c in {a,i}{\',\",\`}; do
        bindkey -M $m $c select-quoted
    done
done
unset m c

# y / p / P use the system clipboard
_clip_yank() { zle vi-yank; print -rn -- "$CUTBUFFER" | wl-copy 2>/dev/null; }
_clip_put() {
    local clip
    clip=$(wl-paste --no-newline 2>/dev/null) && CUTBUFFER=$clip
    zle ${WIDGET##*clip-}
}
zle -N _clip_yank
zle -N clip-vi-put-after _clip_put
zle -N clip-vi-put-before _clip_put
bindkey -M vicmd y _clip_yank p clip-vi-put-after P clip-vi-put-before
bindkey -M visual y _clip_yank

# Block cursor in normal mode, line cursor when typing
zle-keymap-select() { case $KEYMAP in vicmd) print -n '\e[1 q' ;; viins|main) print -n '\e[5 q' ;; esac; }
zle-line-init() { zle -K viins; print -n '\e[5 q'; }
zle -N zle-keymap-select
zle -N zle-line-init
_beam_cursor() { print -n '\e[5 q'; }
add-zsh-hook preexec _beam_cursor

# Auto-pairs: " ' ` ( [ { add their closer; Backspace in an empty pair deletes both
typeset -gA _pairs=( '"' '"' "'" "'" '`' '`' '(' ')' '[' ']' '{' '}' )
_pair_open() {
    emulate -L zsh
    if [[ $KEYS == "$_pairs[$KEYS]" && $RBUFFER[1] == "$KEYS" ]]; then
        (( ++CURSOR ))
    elif [[ $RBUFFER[1] == [[:alnum:]_] || $LBUFFER[-1] == \\ || ( $KEYS == \' && $LBUFFER[-1] == [[:alnum:]_] ) ]]; then
        zle .self-insert
    else
        LBUFFER+=$KEYS RBUFFER=$_pairs[$KEYS]$RBUFFER
    fi
}
_pair_close() {
    if [[ $RBUFFER[1] == "$KEYS" ]]; then (( ++CURSOR )); else zle .self-insert; fi
}
_pair_delete() {
    [[ -n $LBUFFER && -n $RBUFFER && $_pairs[$LBUFFER[-1]] == "$RBUFFER[1]" ]] && RBUFFER=$RBUFFER[2,-1]
    zle .backward-delete-char
}
zle -N _pair_open
zle -N _pair_close
zle -N _pair_delete
for c in '"' "'" '`' '(' '[' '{'; do bindkey -M viins $c _pair_open; done
for c in ')' ']' '}'; do bindkey -M viins $c _pair_close; done
bindkey -M viins '^?' _pair_delete
unset c

# Ctrl+o: yazi, then stay where you quit. Ctrl+f: pick a file, go to its folder.
_yazi_cd() { zle push-line; BUFFER=' y'; zle accept-line; }
_fzf_file_cd() {
    local f
    f=$(fzf </dev/tty) && [[ -n $f ]] || { zle reset-prompt; return 0; }
    zle push-line
    BUFFER=" builtin cd -- ${(q)f:a:h}"
    zle accept-line
}
zle -N _yazi_cd
zle -N _fzf_file_cd
for _km in viins vicmd; do bindkey -M $_km '^o' _yazi_cd '^f' _fzf_file_cd; done; unset _km
bindkey '^[[3~' delete-char
autoload -Uz edit-command-line; zle -N edit-command-line
bindkey '^e' edit-command-line
bindkey -M vicmd '^[[3~' vi-delete-char
bindkey -M vicmd '^e' edit-command-line
bindkey -M visual '^[[3~' vi-delete

function _auto_ls() {
    emulate -L zsh
    (( $+commands[eza] )) || return
    eza --grid --width=$COLUMNS --icons=always --color=always --group-directories-first 2>/dev/null
}
add-zsh-hook chpwd _auto_ls

_zcache zoxide zoxide init zsh --cmd cd
alias z="cd" zi="cdi" c="cd"

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#666666'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_MANUAL_REBIND=1
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='fg=yellow,bold,underline'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='fg=red,bold'
_hist_keys() {
    local km
    for km in viins vicmd; do
        bindkey -M $km '^[[A' $1 '^[OA' $1 '^K' $1 '^[[B' $2 '^[OB' $2 '^J' $2
    done
    bindkey -M vicmd k $1 j $2
}
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
_hist_keys up-line-or-beginning-search down-line-or-beginning-search
_plugins_load() {
    local fd=$1 d=/usr/share/zsh/plugins
    zle -F $fd; exec {fd}<&-
    source $d/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
    source $d/zsh-autosuggestions/zsh-autosuggestions.zsh &&
        _zsh_autosuggest_start && bindkey -M viins '^ ' autosuggest-accept
    source $d/zsh-history-substring-search/zsh-history-substring-search.zsh &&
        _hist_keys history-substring-search-up history-substring-search-down
    unfunction _plugins_load
} 2>/dev/null
if [[ -o zle ]]; then
    exec {_fd}</dev/null; zle -F $_fd _plugins_load; unset _fd
fi

_kill_word_back() { emulate -L zsh; setopt extendedglob; LBUFFER=${LBUFFER%%[^[:space:]]##[[:space:]]#}; }
_kill_word_fwd() { emulate -L zsh; setopt extendedglob; RBUFFER=${RBUFFER##[[:space:]]#[^[:space:]]##}; }
zle -N _kill_word_back
zle -N _kill_word_fwd
for _km in viins vicmd; do
    bindkey -M $_km '^H' _kill_word_back '^W' _kill_word_fwd
done
bindkey -M viins -r '^B'
unset _km
