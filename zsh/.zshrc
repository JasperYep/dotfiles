# yazi
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# Zim
ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]]; then
  source /usr/share/zimfw/zimfw.zsh init
fi
source ${ZIM_HOME}/init.zsh

# FZF
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="
  --height 40% --layout=reverse --border --inline-info 
  --color='bg+:#dddddd,fg+:#000000,hl:#d7005f,hl+:#d7005f,pointer:#d7005f,info:#878787'
"
export FZF_CTRL_T_OPTS="
  --preview 'bat --style=numbers --color=always --theme=GitHub {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"
export FZF_CTRL_R_OPTS="--sort --exact"

alias vi='/usr/bin/vim'
alias vim='nvim'
alias cblue='bluetoothctl connect 1C:7A:43:82:5A:B3'

# Keep your existing local env loader
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# --- Begin Tools Config ---
export TOOLS="$HOME/tools"

# 1. Android
export ANDROID_HOME="$TOOLS/Android/Sdk"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# 2. CodeQL
export CODEQL_HOME="$TOOLS/codeql"
export PATH="$CODEQL_HOME:$PATH"

# 3. Flutter
export PATH="$TOOLS/flutter/bin:$PATH"

# 4. Other
export CHROME_EXECUTABLE=/usr/bin/google-chrome-stable

# --- End Tools Config ---




# # >>> conda initialize >>>
# # !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('/home/jasper/tools/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "/home/jasper/tools/miniconda3/etc/profile.d/conda.sh" ]; then
#         . "/home/jasper/tools/miniconda3/etc/profile.d/conda.sh"
#     else
#         export PATH="/home/jasper/tools/miniconda3/bin:$PATH"
#     fi
# fi
# unset __conda_setup
# # <<< conda initialize <<<
#
