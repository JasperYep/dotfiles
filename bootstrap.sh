#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/dotfiles"
REPO="https://github.com/JasperYep/dotfiles.git"

# ── 颜色 ──────────────────────────────────────────────────────────────────────
green() { printf '\e[32m%s\e[0m\n' "$*"; }
blue()  { printf '\e[34m%s\e[0m\n' "$*"; }
die()   { printf '\e[31mERROR: %s\e[0m\n' "$*" >&2; exit 1; }

# ── 1. clone dotfiles ─────────────────────────────────────────────────────────
blue "==> dotfiles"
if [[ ! -d "$DOTFILES/.git" ]]; then
  git clone "$REPO" "$DOTFILES"
else
  green "    already cloned, skipping"
fi

# ── 2. paru ───────────────────────────────────────────────────────────────────
blue "==> paru"
if ! command -v paru &>/dev/null; then
  sudo pacman -S --needed --noconfirm git base-devel
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/paru.git "$tmp/paru"
  (cd "$tmp/paru" && makepkg -si --noconfirm)
  rm -rf "$tmp"
else
  green "    already installed, skipping"
fi

# ── 3. 官方源包 ───────────────────────────────────────────────────────────────
blue "==> pacman packages"
paru -S --needed --noconfirm - < "$DOTFILES/pkgs/pacman.txt"

# ── 4. AUR 包 ─────────────────────────────────────────────────────────────────
blue "==> AUR packages"
paru -S --needed --noconfirm - < "$DOTFILES/pkgs/aur.txt"

# ── 5. stow ───────────────────────────────────────────────────────────────────
blue "==> stow dotfiles"
cd "$DOTFILES"

MODULES=(
  hyprland
  waybar
  rofi
  nvim
  kitty
  yazi
  tmux
  mako
  zsh
  starship
  scripts
)

for mod in "${MODULES[@]}"; do
  if [[ -d "$DOTFILES/$mod" ]]; then
    stow --restow "$mod" && green "    stowed: $mod" || printf '\e[33m    WARN: stow %s failed (conflict?)\e[0m\n' "$mod"
  fi
done

# ── 6. zimfw ──────────────────────────────────────────────────────────────────
blue "==> zimfw"
ZIM_HOME="${ZDOTDIR:-$HOME}/.zim"
if [[ ! -d "$ZIM_HOME" ]]; then
  zsh -c 'source ~/.zshrc' 2>/dev/null || true
else
  green "    already installed, skipping"
fi

green ""
green "Bootstrap complete. Re-login or: exec zsh"
