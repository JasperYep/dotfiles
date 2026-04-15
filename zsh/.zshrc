# --- History ---
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=100000
export SAVEHIST=100000

setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FCNTL_LOCK
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# --- Plugins ---
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#9ca0b0'  # Catppuccin Latte overlay0
if [[ "$OSTYPE" == "darwin"* ]]; then
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
else
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

# --- FZF (Catppuccin Latte) ---
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="
  --height 40% --layout=reverse --border --inline-info
  --color='bg:#eff1f5,bg+:#ccd0da,fg:#4c4f69,fg+:#4c4f69,hl:#d20f39,hl+:#d20f39,header:#8839ef,info:#8839ef,pointer:#dc8a78,marker:#dc8a78,prompt:#209fb5,spinner:#179299,border:#bcc0cc'
"
export FZF_CTRL_T_OPTS="
  --preview 'bat --style=numbers --color=always --theme=GitHub {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"
export FZF_CTRL_R_OPTS="--sort --exact"

# --- Navigation ---
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}
function j() { z "$@" || y "$@" }
function f() { fd --type f --hidden --follow --exclude .git | fzf }
function fcold() { fd . /mnt/data --type f --hidden --follow --exclude .git | fzf }

# --- Aliases ---
alias vim='nvim'
alias vi='/usr/bin/vim'
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -l --git'
alias la='eza --icons --group-directories-first -la --git'
alias lt='eza --icons --tree --level=2'
alias xz='rsync -azvP'
alias cpusb='rsync -avP && sync'
alias cblue='bluetoothctl connect AC:33:28:09:CC:52'

# --- tmux ---
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tm='tmux new-session -A -s'

# --- PATH ---
export PATH="$HOME/.npm-global/bin:$HOME/.bun/bin:$PATH"

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
