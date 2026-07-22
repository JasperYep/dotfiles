# Theme: dark — sourced by ~/.zshrc
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6e738d'  # Catppuccin Macchiato overlay0
export FZF_DEFAULT_OPTS="
  --height 40% --layout=reverse --border --inline-info
  --color='bg:#24273a,bg+:#363a4f,fg:#cad3f5,fg+:#cad3f5,hl:#ed8796,hl+:#ed8796,header:#c6a0f6,info:#c6a0f6,pointer:#f4dbd6,marker:#f4dbd6,prompt:#7dc4e4,spinner:#8bd5ca,border:#494d64'
"
# $'...' so nested --theme="..." does not break the assignment
export FZF_CTRL_T_OPTS=$'
  --scheme=path
  --preview \'if [ -d {} ]; then eza -la --icons --group-directories-first {} 2>/dev/null || ls -la {}; else bat --style=numbers --color=always --theme="Catppuccin Macchiato" {} 2>/dev/null || file {}; fi\'
  --bind \'ctrl-/:change-preview-window(down|hidden|)\'
'
