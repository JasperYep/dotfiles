# Theme: light — sourced by ~/.zshrc
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#9893a5'  # Rosé Pine Dawn muted
export FZF_DEFAULT_OPTS="
  --height 40% --layout=reverse --border --inline-info
  --color='bg:#faf4ed,bg+:#dfdad9,fg:#575279,fg+:#575279,hl:#b4637a,hl+:#b4637a,header:#907aa9,info:#907aa9,pointer:#d7827e,marker:#d7827e,prompt:#286983,spinner:#56949f,border:#cecacd'
"
export FZF_CTRL_T_OPTS=$'
  --scheme=path
  --preview \'if [ -d {} ]; then eza -la --icons --group-directories-first {} 2>/dev/null || ls -la {}; else bat --style=numbers --color=always --theme=ansi {} 2>/dev/null || file {}; fi\'
  --bind \'ctrl-/:change-preview-window(down|hidden|)\'
'
