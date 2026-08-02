#!/usr/bin/env bash
# Restore the public Arch workstation environment from a reviewed local clone.
set -Eeuo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
MODULES=(
  hyprland waybar rofi ghostty nvim yazi tmux zsh
  fcitx5 ripgrep vscode xdg scripts tt pi
)
STOW_IGNORE_ARGS=(
  --ignore='(^|/)\.claude($|/)'
  --ignore='(^|/)auth\.json$'
  --ignore='(^|/)node_modules($|/)'
  --ignore='(^|/)__pycache__($|/)'
  --ignore='\.py[cod]$'
  --ignore='(^|/)host\.(conf|lua)$'
  --ignore='(^|/)schedule\.json$'
  --ignore='(^|/)(subscription\.env|installation\.yaml|user\.yaml)$'
  --ignore='(^|/)(sync|generated|.*\.userdb)($|/)'
  --ignore='(^|/)\.env($|\.)'
  --ignore='\.(key|pem|p12|pfx|log)$'
  --ignore='(^|/)lazy-lock\.json$'
)
MANIFEST_NAMES=(official aur flatpak npm)
KNOWN_PROFILES=(academic documents dev ai media communication infra remote)

SELECTED_PROFILES=()
FULL_MODE=0
DRY_RUN=0

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

is_valid_profile() {
  local candidate="$1" item
  for item in "${KNOWN_PROFILES[@]}"; do
    [[ "$candidate" == "$item" ]] && return 0
  done
  return 1
}

parse_profile_csv() {
  local csv="$1" profile
  IFS=',' read -r -a raw_profiles <<<"$csv"
  for profile in "${raw_profiles[@]}"; do
    profile="$(echo "$profile" | xargs)"
    [[ -n "$profile" ]] || continue
    if ! is_valid_profile "$profile"; then
      die "unknown profile: $profile (valid: ${KNOWN_PROFILES[*]})"
    fi
    SELECTED_PROFILES+=("$profile")
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with)
        [[ $# -gt 1 ]] || die "--with requires a profile CSV list"
        parse_profile_csv "$2"
        shift 2
        ;;
      --with=*)
        parse_profile_csv "${1#*=}"
        shift
        ;;
      --full)
        FULL_MODE=1
        shift
        ;;
      --plan|--dry-run)
        DRY_RUN=1
        shift
        ;;
      --list-profiles)
        printf '%s\n' "Available restore profiles:"
        local profile
        for profile in "${KNOWN_PROFILES[@]}"; do
          printf '  - %s\n' "$profile"
        done
        exit 0
        ;;
      -h|--help)
        printf '%s\n' \
          "usage: bootstrap.sh [--with PROFILE_CSV] [--full] [--plan] [--list-profiles]" \
          "  --with PROFILE_CSV  install core plus comma-separated profiles" \
          "  --full              install core and all known profiles" \
          "  --plan              print the restore plan without making changes" \
          "  --list-profiles     show supported optional profiles"
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done

  if [[ $FULL_MODE -eq 1 ]]; then
    SELECTED_PROFILES=("${KNOWN_PROFILES[@]}")
  fi

  if ((${#SELECTED_PROFILES[@]} > 0)); then
    mapfile -t SELECTED_PROFILES < <(printf '%s\n' "${SELECTED_PROFILES[@]}" | LC_ALL=C sort -u)
  fi
}

collect_manifest_items() {
  local manifest_name="$1"
  local item path
  local -a items=()

  path="$DOTFILES/pkgs/core/$manifest_name.txt"
  if [[ -f "$path" ]]; then
    while IFS= read -r item || [[ -n "$item" ]]; do
      [[ -n "$item" ]] && items+=("$item")
    done <"$path"
  fi

  local profile
  for profile in "${SELECTED_PROFILES[@]}"; do
    path="$DOTFILES/pkgs/profiles/$profile/$manifest_name.txt"
    if [[ -f "$path" ]]; then
      while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -n "$item" ]] && items+=("$item")
      done <"$path"
    fi
  done

  if ((${#items[@]} > 0)); then
    printf '%s\n' "${items[@]}" | LC_ALL=C sort -u
  fi
}

validate_manifest_file() {
  local path="$1"
  [[ -f "$path" ]] || die "manifest file missing: $path"
  [[ -s "$path" ]] || return 0
  LC_ALL=C sort -cu "$path" || die "manifest must be sorted and unique: $path"
  ! grep -nE '^[[:space:]]*$|^[[:space:]]|[[:space:]]$' "$path" >/dev/null \
    || die "blank or padded line in manifest: $path"
}

manifest_paths_for_kind() {
  local name="$1" profile path
  printf '%s\n' "$DOTFILES/pkgs/core/$name.txt"
  for profile in "${KNOWN_PROFILES[@]}"; do
    path="$DOTFILES/pkgs/profiles/$profile/$name.txt"
    if [[ -f "$path" ]]; then
      printf '%s\n' "$path"
    fi
  done
}

validate_manifest_tree() {
  local name profile path item previous basename relative valid
  local top_manifest core_manifest
  local -A seen=() official_items=()

  [[ -d "$DOTFILES/pkgs/profiles" ]] || die "missing profile directory: pkgs/profiles"
  for profile in "${KNOWN_PROFILES[@]}"; do
    [[ -d "$DOTFILES/pkgs/profiles/$profile" ]] \
      || die "missing expected profile directory: pkgs/profiles/$profile"
  done
  for path in "$DOTFILES"/pkgs/profiles/*; do
    [[ -d "$path" ]] || continue
    is_valid_profile "$(basename "$path")" \
      || die "unknown profile directory: ${path#"$DOTFILES/"}"
  done

  while IFS= read -r path; do
    basename="${path##*/}"
    relative="${path#"$DOTFILES/pkgs/"}"
    valid=0
    for name in "${MANIFEST_NAMES[@]}"; do
      if [[ "$basename" == "$name.txt" ]]; then
        valid=1
        break
      fi
    done
    [[ $valid -eq 1 ]] || die "unknown manifest type: pkgs/$relative"
  done < <(find "$DOTFILES/pkgs" -type f -name '*.txt' -print)

  for name in "${MANIFEST_NAMES[@]}"; do
    core_manifest="$DOTFILES/pkgs/core/$name.txt"
    top_manifest="$DOTFILES/pkgs/$name.txt"
    validate_manifest_file "$core_manifest"
    validate_manifest_file "$top_manifest"
    cmp -s "$top_manifest" "$core_manifest" \
      || die "top-level manifest $top_manifest does not match $core_manifest"

    seen=()
    while IFS= read -r path; do
      validate_manifest_file "$path"
      while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -n "$item" ]] || continue
        if [[ -n "${seen[$item]+x}" ]]; then
          previous="${seen[$item]}"
          die "duplicate $name item '$item' in ${previous#"$DOTFILES/"} and ${path#"$DOTFILES/"}"
        fi
        seen[$item]="$path"
        if [[ "$name" == official ]]; then
          official_items[$item]="$path"
        fi
      done <"$path"
    done < <(manifest_paths_for_kind "$name")
  done

  while IFS= read -r path; do
    while IFS= read -r item || [[ -n "$item" ]]; do
      [[ -n "$item" ]] || continue
      if [[ -n "${official_items[$item]+x}" ]]; then
        die "package '$item' appears in official and AUR manifests"
      fi
    done <"$path"
  done < <(manifest_paths_for_kind aur)
}

preflight() {
  [[ $EUID -ne 0 ]] || die "run as a normal user, not root"
  [[ -f /etc/arch-release ]] || die "this bootstrap supports Arch Linux only"
  [[ -d "$DOTFILES/.git" ]] || die "run bootstrap.sh from a local Git clone"
  require_command git
  require_command sudo

  [[ -z "$(git -C "$DOTFILES" status --porcelain)" ]] \
    || die "dotfiles worktree must be clean before restore"
  validate_manifest_tree
  if [[ $DRY_RUN -eq 0 ]]; then
    sudo -v
  fi
}

install_pacman_items() {
  local -a items=()
  mapfile -t items < <(collect_manifest_items "official")
  if ((${#items[@]} > 0)); then
    blue "Install official Arch packages (${#items[@]} packages)"
    sudo pacman -S --needed -- "${items[@]}"
  fi
}

ensure_paru() {
  local build_dir
  command -v paru >/dev/null && return

  blue "Install paru-bin from the AUR"
  build_dir="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru-bin.git "$build_dir/paru-bin"
  (cd "$build_dir/paru-bin" && makepkg -si --needed)
  rm -rf "$build_dir"
}

install_aur_items() {
  local -a items=()
  mapfile -t items < <(collect_manifest_items "aur")
  if ((${#items[@]} > 0)); then
    ensure_paru
    blue "Install AUR packages (${#items[@]} packages, interactive PKGBUILD review)"
    paru -S --needed -- "${items[@]}"
  fi
}

install_maple_mono() {
  local archive checksum destination temporary
  if fc-match -f '%{family}\n' 'Maple Mono NF CN' | grep -Fq 'Maple Mono NF CN'; then
    return
  fi

  blue "Install Maple Mono NF CN for current user"
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

install_flatpak_items() {
  local -a items=()
  mapfile -t items < <(collect_manifest_items "flatpak")
  if ((${#items[@]} > 0)); then
    blue "Install Flatpak applications (${#items[@]} apps)"
    sudo flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install --system -y flathub "${items[@]}"
  fi
}

install_pi() {
  local installer launcher target
  launcher="$HOME/.local/bin/pi"
  target="$HOME/.local/lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js"

  if [[ -e "$HOME/.npm-global/bin/pi" || -L "$HOME/.npm-global/bin/pi" ]]; then
    blue "Remove legacy npm-global Pi installation"
    npm uninstall --global --prefix "$HOME/.npm-global" \
      @earendil-works/pi-coding-agent
  fi

  if [[ -x "$launcher" && "$(readlink -f "$launcher")" == "$target" ]]; then
    return
  fi
  if [[ -e "$launcher" || -L "$launcher" ]]; then
    die "refusing unmanaged Pi launcher: $launcher"
  fi

  blue "Install Pi with official installer"
  installer="$(mktemp)"
  curl --fail --location --retry 3 --retry-all-errors \
    --connect-timeout 10 --max-time 300 \
    https://pi.dev/install.sh -o "$installer"
  if ! NPM_CONFIG_PREFIX="$HOME/.local" setsid -f -w sh "$installer"; then
    rm -f "$installer"
    die "official Pi installer failed"
  fi
  rm -f "$installer"

  [[ -x "$launcher" && "$(readlink -f "$launcher")" == "$target" ]] \
    || die "official Pi installation did not create $launcher"
}

install_npm_items() {
  local -a items=()
  mapfile -t items < <(collect_manifest_items "npm")
  if ((${#items[@]} > 0)); then
    blue "Install global npm tools (${#items[@]} packages)"
    npm config set prefix "$HOME/.npm-global" --location=user
    npm install --global \
      --allow-scripts=@github/keytar,node-pty,@google/genai,protobufjs \
      -- "${items[@]}"
  fi
}

install_packages() {
  install_pacman_items
  install_aur_items
  install_maple_mono
  install_flatpak_items
  install_pi
  install_npm_items
}

deploy_dotfiles() {
  blue "Deploy dotfiles"
  stow --dir="$DOTFILES" --target="$HOME" --no-folding "${STOW_IGNORE_ARGS[@]}" --simulate --restow "${MODULES[@]}"
  stow --dir="$DOTFILES" --target="$HOME" --no-folding "${STOW_IGNORE_ARGS[@]}" --restow "${MODULES[@]}"

  if [[ ! -e "$HOME/.config/hypr/host.lua" ]]; then
    if [[ -e "$HOME/.config/hypr/host.conf" ]]; then
      die "legacy host.conf exists; migrate it to ~/.config/hypr/host.lua before restore"
    fi
    install -Dm0644 "$DOTFILES/hyprland/.config/hypr/host.example.lua" \
      "$HOME/.config/hypr/host.lua"
  fi
  install -Dm0644 "$DOTFILES/nvim/.config/nvim/lazy-lock.json" \
    "$HOME/.config/nvim/lazy-lock.json"

  local unit
  for unit in daily-wallpaper.service daily-wallpaper.timer tt.service; do
    install -Dm0644 "$DOTFILES/systemd/.config/systemd/user/$unit" \
      "$HOME/.config/systemd/user/$unit"
  done

  if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  fi

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

print_plan() {
  local -a official aur flatpak npm
  mapfile -t official < <(collect_manifest_items "official")
  mapfile -t aur < <(collect_manifest_items "aur")
  mapfile -t flatpak < <(collect_manifest_items "flatpak")
  mapfile -t npm < <(collect_manifest_items "npm")

  blue "Restore plan summary"
  printf 'Selected profiles (%d): %s\n' \
    "${#SELECTED_PROFILES[@]}" \
    "${SELECTED_PROFILES[*]:-none (core only)}"
  printf 'Official packages    : %d\n' "${#official[@]}"
  printf 'AUR packages         : %d\n' "${#aur[@]}"
  printf 'Flatpak applications : %d\n' "${#flatpak[@]}"
  printf 'Global npm tools     : %d (plus official Pi installer)\n' "${#npm[@]}"
  printf 'Direct core asset    : Maple Mono NF CN\n'
  if ((${#aur[@]} > 0)); then
    printf 'AUR helper bootstrap : paru-bin when paru is absent\n'
  fi

  local -a skipped=()
  local profile
  for profile in "${KNOWN_PROFILES[@]}"; do
    if ! is_valid_profile "$profile" || ! (printf '%s\n' "${SELECTED_PROFILES[@]}" | grep -Fqx "$profile"); then
      skipped+=("$profile")
    fi
  done
  if ((${#skipped[@]} > 0)); then
    printf 'Skipped profiles (%d) : %s\n' "${#skipped[@]}" "${skipped[*]}"
  fi
}

main() {
  parse_args "$@"
  preflight

  print_plan

  if [[ $DRY_RUN -eq 1 ]]; then
    green "Dry-run complete. No changes were made."
    exit 0
  fi

  install_packages
  deploy_dotfiles
  bootstrap_editors
  configure_user_services

  blue "Verify restore"
  if ((${#SELECTED_PROFILES[@]} > 0)); then
    local csv
    csv="$(IFS=,; echo "${SELECTED_PROFILES[*]}")"
    "$DOTFILES/verify.sh" --with "$csv"
  else
    "$DOTFILES/verify.sh"
  fi

  green "Public workstation restore complete."
  printf '%s\n' \
    "Log out, log in on TTY1, and run: start-hyprland" \
    "Then run: $DOTFILES/verify.sh --session" \
    "Private Rime state, secrets, research data, and private services were not restored."
}

main "$@"
