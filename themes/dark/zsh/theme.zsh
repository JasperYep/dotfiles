# Theme: dark — sourced by ~/.zshrc
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6e6a86'  # Rosé Pine Moon muted
export FZF_DEFAULT_OPTS="
  --height 40% --layout=reverse --border --inline-info
  --color='bg:#232136,bg+:#44415a,fg:#e0def4,fg+:#e0def4,hl:#eb6f92,hl+:#eb6f92,header:#c4a7e7,info:#c4a7e7,pointer:#ea9a97,marker:#ea9a97,prompt:#9ccfd8,spinner:#9ccfd8,border:#56526e'
"
# $'...' so nested --theme="..." does not break the assignment
export FZF_CTRL_T_OPTS=$'
  --scheme=path
  --preview \'if [ -d {} ]; then eza -la --icons --group-directories-first {} 2>/dev/null || ls -la {}; else bat --style=numbers --color=always --theme=ansi {} 2>/dev/null || file {}; fi\'
  --bind \'ctrl-/:change-preview-window(down|hidden|)\'
'
