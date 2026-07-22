# History
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=100000
export SAVEHIST=100000
setopt APPEND_HISTORY EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST
setopt HIST_FCNTL_LOCK HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY

# Completion and navigation
autoload -Uz compinit
compinit
eval "$(zoxide init zsh)"

export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/config"
export FZF_DEFAULT_COMMAND='fd . "$HOME" --hidden --follow --type f --type d --type l --exclude .git --exclude node_modules --exclude .venv --exclude __pycache__ --exclude .cache --exclude .local/share --exclude .local/state'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd . "$HOME" --hidden --follow --type d --exclude .git --exclude node_modules --exclude .venv --exclude __pycache__ --exclude .cache --exclude .local/share --exclude .local/state'
export FZF_ALT_C_OPTS="--scheme=path --preview 'eza -la --icons --group-directories-first {} 2>/dev/null || ls -la {}'"
export FZF_CTRL_R_OPTS="--sort"

if [[ -o interactive && "${TERM:-}" != dumb ]]; then
  bindkey -v
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  source /usr/share/fzf/key-bindings.zsh
  eval "$(starship init zsh)"

  theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/theme/current/zsh/theme.zsh"
  [[ -f "$theme_file" ]] && source "$theme_file"

  bindkey -M vicmd '^R' redo
  bindkey -M viins '^?' backward-delete-char
fi

# PATH and defaults
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.bun/bin:$PATH"
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--FRX --mouse --wheel-lines=3}"
export COLORTERM="${COLORTERM:-truecolor}"

# Yazi directory-changing wrapper
y() {
  local tmp cwd
  tmp="$(mktemp -t 'yazi-cwd.XXXXXX')"
  if [[ -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-}" ]]; then
    YAZI_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/yazi-ssh" command yazi "$@" --cwd-file="$tmp"
  else
    command yazi "$@" --cwd-file="$tmp"
  fi
  cwd="$(<"$tmp")"
  [[ -n "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

goto() {
  local file="${1%:*}"
  local line="${1##*:}"
  nvim +"$line" "$file"
}

rp() {
  local path
  path="$(realpath "$1")"
  printf '%s' "$path" | wl-copy
  printf '已复制：%s\n' "$path"
}

alias vi='nvim'
alias vim='nvim'
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -l --git'
alias la='eza --icons --group-directories-first -la --git'
alias lt='eza --icons --tree --level=2'
alias xz='rsync -azvP'
alias cpusb='rsync -avP && sync'
alias fm='nautilus --new-window . &>/dev/null &'
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tm='tmux new-session -A -s'
alias tls='tmux list-sessions'
alias grep='grep --color=auto'

# A remote client may not have Ghostty terminfo installed.
if [[ "${TERM:-}" == xterm-ghostty ]] && ! infocmp xterm-ghostty >/dev/null 2>&1; then
  export TERM=xterm-256color
fi
