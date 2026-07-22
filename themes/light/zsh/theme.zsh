# Theme: light — sourced by ~/.zshrc
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#9ca0b0'  # Catppuccin Latte overlay0
export FZF_DEFAULT_OPTS="
  --height 40% --layout=reverse --border --inline-info
  --color='bg:#eff1f5,bg+:#ccd0da,fg:#4c4f69,fg+:#4c4f69,hl:#d20f39,hl+:#d20f39,header:#8839ef,info:#8839ef,pointer:#dc8a78,marker:#dc8a78,prompt:#209fb5,spinner:#179299,border:#bcc0cc'
"
export FZF_CTRL_T_OPTS=$'
  --scheme=path
  --preview \'if [ -d {} ]; then eza -la --icons --group-directories-first {} 2>/dev/null || ls -la {}; else bat --style=numbers --color=always --theme=GitHub {} 2>/dev/null || file {}; fi\'
  --bind \'ctrl-/:change-preview-window(down|hidden|)\'
'
