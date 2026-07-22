#!/usr/bin/env bash
# Restore the public Arch workstation environment from a reviewed local clone.
set -Eeuo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES=(
  hyprland waybar rofi ghostty nvim yazi tmux zsh
  fcitx5 ripgrep vscode xdg scripts tt
)
STOW_IGNORE_ARGS=(
  --ignore='(^|/)\.claude($|/)'
  --ignore='(^|/)__pycache__($|/)'
  --ignore='\.py[cod]$'
  --ignore='(^|/)host\.conf$'
  --ignore='(^|/)schedule\.json$'
  --ignore='(^|/)(subscription\.env|installation\.yaml|user\.yaml)$'
  --ignore='(^|/)(sync|generated|.*\.userdb)($|/)'
  --ignore='(^|/)\.env($|\.)'
  --ignore='\.(key|pem|p12|pfx|log)$'
  --ignore='(^|/)lazy-lock\.json$'
)
MANIFESTS=(official aur flatpak npm uv vscode-extensions)

blue() { printf '\e[34m==> %s\e[0m\n' "$*"; }
green() { printf '\e[32m%s\e[0m\n' "$*"; }
die() { printf '\e[31mERROR: %s\e[0m\n' "$*" >&2; exit 1; }

on_error() {
  local status=$?
  printf '\e[31mFAILED: %s (line %s)\e[0m\n' "${BASH_COMMAND}" "${BASH_LINENO[0]}" >&2
  exit "$status"
}
trap on_error ERR

require_command() {
  command -v "$1" >/dev/null || die "missing required command: $1"
}

read_manifest() {
  local path="$1"
  mapfile -t MANIFEST_ITEMS <"$path"
  ((${#MANIFEST_ITEMS[@]} > 0)) || die "empty manifest: $path"
}

validate_manifest() {
  local path="$1"
  [[ -s "$path" ]] || die "missing or empty manifest: $path"
  LC_ALL=C sort -cu "$path" || die "manifest must be sorted and unique: $path"
  if grep -q '^$' "$path"; then
    die "blank line in manifest: $path"
  fi
}

validate_manifests() {
  local name
  for name in "${MANIFESTS[@]}"; do
    validate_manifest "$DOTFILES/pkgs/$name.txt"
  done

  local overlap
  overlap="$(LC_ALL=C comm -12 "$DOTFILES/pkgs/official.txt" "$DOTFILES/pkgs/aur.txt")"
  [[ -z "$overlap" ]] || die "package appears in official and AUR manifests: $overlap"
}

preflight() {
  [[ $EUID -ne 0 ]] || die "run as a normal user, not root"
  [[ -f /etc/arch-release ]] || die "this bootstrap supports Arch Linux only"
  [[ -d "$DOTFILES/.git" ]] || die "run bootstrap.sh from a local Git clone"
  require_command git
  require_command sudo

  [[ -z "$(git -C "$DOTFILES" status --porcelain)" ]] \
    || die "dotfiles worktree must be clean before restore"
  validate_manifests
  sudo -v
}

install_pacman_manifest() {
  local path="$1"
  read_manifest "$path"
  sudo pacman -S --needed -- "${MANIFEST_ITEMS[@]}"
}

ensure_paru() {
  local build_dir
  command -v paru >/dev/null && return

  blue "Build paru from the AUR"
  build_dir="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru.git "$build_dir/paru"
  (cd "$build_dir/paru" && makepkg -si --needed)
  rm -rf "$build_dir"
}

install_maple_mono() {
  local archive checksum destination temporary
  if fc-match -f '%{family}\n' 'Maple Mono NF CN' | grep -Fq 'Maple Mono NF CN'; then
    return
  fi

  blue "Install Maple Mono NF CN for the current user"
  archive='https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-NF-CN.zip'
  checksum='af913b6322905348b3f50e4397fedc35b3a880db5effcce7969003051dcd3e94'
  destination="$HOME/.local/share/fonts/MapleMono-NF-CN"
  temporary="$(mktemp -d)"
  curl --fail --location --retry 3 --retry-all-errors \
    --connect-timeout 10 --max-time 300 \
    "$archive" -o "$temporary/maple.zip"
  printf '%s  %s\n' "$checksum" "$temporary/maple.zip" | sha256sum --check --status
  rm -rf "$destination"
  mkdir -p "$destination"
  unzip -q "$temporary/maple.zip" -d "$destination"
  rm -rf "$temporary"
  fc-cache -f "$destination"
}

install_packages() {
  local package version spec
  blue "Install official user-experience packages"
  install_pacman_manifest "$DOTFILES/pkgs/official.txt"

  ensure_paru
  blue "Install AUR packages (interactive PKGBUILD review)"
  read_manifest "$DOTFILES/pkgs/aur.txt"
  paru -S --needed -- "${MANIFEST_ITEMS[@]}"
  install_maple_mono

  blue "Install Flatpak applications"
  sudo flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  read_manifest "$DOTFILES/pkgs/flatpak.txt"
  sudo flatpak install --system -y flathub "${MANIFEST_ITEMS[@]}"

  blue "Install global npm tools"
  npm config set prefix "$HOME/.npm-global" --location=user
  read_manifest "$DOTFILES/pkgs/npm.txt"
  npm install --global \
    --allow-scripts=@github/keytar,node-pty,@google/genai,protobufjs \
    -- "${MANIFEST_ITEMS[@]}"

  blue "Install uv tools"
  while IFS= read -r spec; do
    package="${spec%%==*}"
    version="${spec#*==}"
    if ! uv tool list | grep -Fqx "$package v$version"; then
      uv tool install --force "$spec"
    fi
  done <"$DOTFILES/pkgs/uv.txt"

  blue "Install VS Code extensions"
  while IFS= read -r extension; do
    code --install-extension "$extension" --force
  done <"$DOTFILES/pkgs/vscode-extensions.txt"
}

deploy_dotfiles() {
  blue "Deploy dotfiles"
  stow --dir="$DOTFILES" --target="$HOME" --no-folding "${STOW_IGNORE_ARGS[@]}" --simulate --restow "${MODULES[@]}"
  stow --dir="$DOTFILES" --target="$HOME" --no-folding "${STOW_IGNORE_ARGS[@]}" --restow "${MODULES[@]}"

  if [[ ! -e "$HOME/.config/hypr/host.conf" ]]; then
    install -Dm0644 "$DOTFILES/hyprland/.config/hypr/host.example.conf" \
      "$HOME/.config/hypr/host.conf"
  fi
  install -Dm0644 "$DOTFILES/nvim/.config/nvim/lazy-lock.json" \
    "$HOME/.config/nvim/lazy-lock.json"

  local unit
  for unit in daily-wallpaper.service daily-wallpaper.timer tt.service; do
    install -Dm0644 "$DOTFILES/systemd/.config/systemd/user/$unit" \
      "$HOME/.config/systemd/user/$unit"
  done

  "$HOME/.local/bin/theme-switch" apply
  sudo chsh -s "$(command -v zsh)" "$USER"
}

bootstrap_editors() {
  blue "Restore pinned Neovim plugins and Treesitter parsers"
  nvim --headless '+Lazy! restore' +qa
  [[ -x /usr/bin/tree-sitter ]] || die "missing Arch tree-sitter CLI: /usr/bin/tree-sitter"
  PATH="/usr/bin:$PATH" nvim --headless \
    "+lua require('nvim-treesitter').install(require('core.treesitter_languages')):wait(600000)" \
    +qa
}

configure_user_services() {
  blue "Configure public user services"
  systemctl --user daemon-reload
  if [[ ! -f "$HOME/Pictures/today-wallpaper.jpg" ]]; then
    systemctl --user start daily-wallpaper.service
  fi
  systemctl --user enable --now daily-wallpaper.timer

  if [[ -f "$HOME/.config/tt/schedule.json" ]]; then
    if ! "$HOME/.local/bin/tt" validate; then
      if systemctl --user is-enabled --quiet tt.service; then
        systemctl --user disable --now tt.service
      fi
      die "private tt schedule is invalid"
    fi
    systemctl --user enable tt.service
    systemctl --user restart tt.service
  elif systemctl --user is-enabled --quiet tt.service; then
    systemctl --user disable --now tt.service
  fi
}

main() {
  preflight
  install_packages
  deploy_dotfiles
  bootstrap_editors
  configure_user_services

  blue "Verify restore"
  "$DOTFILES/verify.sh"

  green "Public workstation restore complete."
  printf '%s\n' \
    "Log out, log in on TTY1, and run: start-hyprland" \
    "Then run: $DOTFILES/verify.sh --session" \
    "Private Rime state, secrets, research data, and private services were not restored."
}

main "$@"
