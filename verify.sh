#!/usr/bin/env bash
# Verify repository integrity, installed state, and optionally the live Hyprland session.
set -Eeuo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="installed"
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

pass() { printf '\e[32mPASS\e[0m %s\n' "$*"; }
fail() { printf '\e[31mFAIL\e[0m %s\n' "$*" >&2; exit 1; }

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
      fail "unknown profile: $profile (valid: ${KNOWN_PROFILES[*]})"
    fi
    SELECTED_PROFILES+=("$profile")
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-only|installed|--session)
        MODE="$1"
        shift
        ;;
      --with)
        [[ $# -gt 1 ]] || fail "--with requires a profile CSV list"
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
      -h|--help)
        printf '%s\n' \
          "usage: verify.sh [--repo-only|installed|--session] [--with PROFILE_CSV] [--full]"
        exit 0
        ;;
      *)
        fail "unknown argument: $1"
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
  [[ -f "$path" ]] || fail "manifest file missing: $path"
  [[ -s "$path" ]] || return 0
  LC_ALL=C sort -cu "$path" || fail "manifest is not sorted and unique: $path"
  ! grep -nE '^[[:space:]]*$|^[[:space:]]|[[:space:]]$' "$path" >/dev/null \
    || fail "blank or padded line in manifest: $path"
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

validate_manifests() {
  local name profile path item previous basename relative valid
  local top_manifest core_manifest
  local -A seen=() official_items=()

  [[ -d "$DOTFILES/pkgs/profiles" ]] || fail "missing profile directory: pkgs/profiles"
  for profile in "${KNOWN_PROFILES[@]}"; do
    [[ -d "$DOTFILES/pkgs/profiles/$profile" ]] \
      || fail "missing expected profile directory: pkgs/profiles/$profile"
  done
  for path in "$DOTFILES"/pkgs/profiles/*; do
    [[ -d "$path" ]] || continue
    is_valid_profile "$(basename "$path")" \
      || fail "unknown profile directory: ${path#"$DOTFILES/"}"
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
    [[ $valid -eq 1 ]] || fail "unknown manifest type: pkgs/$relative"
  done < <(find "$DOTFILES/pkgs" -type f -name '*.txt' -print)

  for name in "${MANIFEST_NAMES[@]}"; do
    core_manifest="$DOTFILES/pkgs/core/$name.txt"
    top_manifest="$DOTFILES/pkgs/$name.txt"
    validate_manifest_file "$core_manifest"
    validate_manifest_file "$top_manifest"
    cmp -s "$top_manifest" "$core_manifest" \
      || fail "top-level manifest $top_manifest does not match $core_manifest"

    seen=()
    while IFS= read -r path; do
      validate_manifest_file "$path"
      while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -n "$item" ]] || continue
        if [[ -n "${seen[$item]+x}" ]]; then
          previous="${seen[$item]}"
          fail "duplicate $name item '$item' in ${previous#"$DOTFILES/"} and ${path#"$DOTFILES/"}"
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
        fail "package '$item' appears in official and AUR manifests"
      fi
    done <"$path"
  done < <(manifest_paths_for_kind aur)

  pass "package manifests"
}

validate_scripts() {
  bash -n "$DOTFILES/bootstrap.sh" "$DOTFILES/verify.sh"
  bash -n "$DOTFILES/scripts/.local/bin/theme-switch"
  bash -n "$DOTFILES/scripts/.local/bin/daily-wallpaper.sh"
  bash -n "$DOTFILES/scripts/.local/bin/rofi-calc"
  bash -n "$DOTFILES/scripts/.local/bin/rofi-files"
  zsh -n "$DOTFILES/zsh/.zshrc"
  sh -n "$DOTFILES/hyprland/.config/hypr/scripts/away-lock.sh"
  sh -n "$DOTFILES/hyprland/.config/hypr/scripts/layout-dispatch.sh"
  sh -n "$DOTFILES/hyprland/.config/hypr/scripts/quicknote.sh"
  luac -p \
    "$DOTFILES/hyprland/.config/hypr/hyprland.lua" \
    "$DOTFILES/hyprland/.config/hypr/host.example.lua" \
    "$DOTFILES/themes/light/hypr/theme.lua" \
    "$DOTFILES/themes/dark/hypr/theme.lua"

  local cache
  cache="$(mktemp -d)"
  PYTHONPYCACHEPREFIX="$cache" python -m py_compile \
    "$DOTFILES/tt/.local/bin/tt" \
    "$DOTFILES/nvim/.config/nvim/bin/render_markdown_latex.py"
  rm -rf "$cache"

  python - "$DOTFILES/tt/.local/bin/tt" <<'PY'
import datetime as dt
import runpy
import sys

module = runpy.run_path(sys.argv[1])
assert module["display_width"]("A中") == 3
assert module["truncate_width"]("A中文", 3) == "A中"
block = {"start": "22:30", "end": "06:30"}
now = dt.datetime(2026, 1, 2, 1, 0)
assert module["block_duration_minutes"](block) == 480
assert module["remaining_minutes"](block, now) == 330
assert module["block_progress"](block, now) == 0.3125
PY

  local script
  for script in rofi-calc rofi-files; do
    [[ -x "$DOTFILES/scripts/.local/bin/$script" ]] \
      || fail "script is not executable: scripts/.local/bin/$script"
  done
  pass "script syntax and helpers"
}

validate_data_files() {
  jq empty "$DOTFILES/vscode/.config/Code/User/settings.json"
  jq empty "$DOTFILES/hyprland/.config/hypr/.luarc.json"
  jq empty "$DOTFILES/tt/.config/tt/schedule.example.json"
  jq empty "$DOTFILES/waybar/.config/waybar/config.jsonc"
  pass "JSON and JSONC files"
}

validate_hyprland_lua() {
  local temporary theme
  temporary="$(mktemp -d)"
  mkdir -p "$temporary/hypr"
  cp "$DOTFILES/hyprland/.config/hypr/hyprland.lua" "$temporary/hypr/hyprland.lua"
  cp "$DOTFILES/hyprland/.config/hypr/host.example.lua" "$temporary/hypr/host.lua"

  for theme in light dark; do
    cp "$DOTFILES/themes/$theme/hypr/theme.lua" "$temporary/hypr/theme.lua"
    if ! XDG_CONFIG_HOME="$temporary" Hyprland --verify-config --config "$temporary/hypr/hyprland.lua" >/dev/null; then
      rm -rf "$temporary"
      fail "Hyprland Lua config validation failed for $theme theme"
    fi
  done

  rm -rf "$temporary"
  pass "Hyprland Lua configuration"
}

validate_stow_sources() {
  local module path relative
  local -a unsafe=()
  for module in "${MODULES[@]}"; do
    while IFS= read -r -d '' path; do
      relative="${path#"$DOTFILES/"}"
      case "$relative" in
        */.claude/*|*/__pycache__/*|*.pyc|*.pyo|*/host.conf|*/host.lua|*/schedule.json|*/subscription.env|*/installation.yaml|*/user.yaml|*.userdb/*|*/sync/*|*/generated/*|*.key|*.pem|*.p12|*.pfx|*.log)
          unsafe+=("$relative")
          ;;
        */.env|*/.env.*)
          [[ "$relative" == *.env.example ]] || unsafe+=("$relative")
          ;;
      esac
    done < <(find "$DOTFILES/$module" \( -type f -o -type l \) -print0)
  done
  ((${#unsafe[@]} == 0)) || fail "private/generated files exist inside Stow modules:\n$(printf '%s\n' "${unsafe[@]}")"
  pass "Stow source boundary"
}

validate_public_boundary() {
  [[ ! -e "$DOTFILES/scripts/.local/bin/win10" ]] || fail "obsolete RDP launcher is still present"
  [[ ! -e "$DOTFILES/nvim/.config/nvim/.nvimlog" ]] || fail "tracked Neovim runtime log is still present"

  local forbidden tracked_private file
  local -a candidates=()
  mapfile -d '' -t candidates < <(
    git -C "$DOTFILES" ls-files --cached --others --exclude-standard -z
  )

  forbidden="$(
    for file in "${candidates[@]}"; do
      [[ -f "$DOTFILES/$file" ]] || continue
      case "$file" in
        verify.sh) continue ;;
      esac
      grep -IHnE \
        'RDP_PASS=|autodl\.pro|/home/jasper|/dev/dri/card[0-9]|monitor=DP-[0-9]|([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' \
        "$DOTFILES/$file" || true
    done
  )"
  [[ -z "$forbidden" ]] || fail "public tree contains host/private values:\n$forbidden"

  tracked_private="$(
    for file in "${candidates[@]}"; do
      [[ -f "$DOTFILES/$file" ]] || continue
      case "$file" in
        */subscription.env|*/schedule.json|*/host.conf|*/host.lua|*/installation.yaml|*/user.yaml|*.userdb/*|*/sync/*|*/generated/*|*.key|*.pem|*.p12|*.pfx|*.log)
          printf '%s\n' "$file"
          ;;
        */.env|*/.env.*)
          [[ "$file" == *.env.example ]] || printf '%s\n' "$file"
          ;;
      esac
    done
  )"
  [[ -z "$tracked_private" ]] || fail "private state is tracked:\n$tracked_private"
  pass "public/private boundary"
}

validate_repository() {
  validate_manifests
  validate_scripts
  validate_data_files
  validate_hyprland_lua
  validate_stow_sources
  validate_public_boundary
}

verify_pacman_packages() {
  local -a official=() aur=()
  mapfile -t official < <(collect_manifest_items "official")
  mapfile -t aur < <(collect_manifest_items "aur")

  local missing
  if ((${#official[@]} > 0)); then
    if ! missing="$(pacman -T "${official[@]}")"; then
      fail "missing official packages: $missing"
    fi
  fi
  if ((${#aur[@]} > 0)); then
    if ! missing="$(pacman -T "${aur[@]}")"; then
      fail "missing AUR packages: $missing"
    fi
  fi
  pass "Pacman and AUR packages"
}

verify_flatpak_packages() {
  local -a items=()
  mapfile -t items < <(collect_manifest_items "flatpak")
  local app
  for app in "${items[@]}"; do
    flatpak info --system "$app" >/dev/null || fail "missing Flatpak application: $app"
  done
  pass "Flatpak applications"
}

verify_pi() {
  local launcher target version
  launcher="$HOME/.local/bin/pi"
  target="$HOME/.local/lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js"
  [[ -x "$launcher" ]] || fail "Pi launcher is missing: $launcher"
  [[ "$(readlink -f "$launcher")" == "$target" ]] \
    || fail "Pi is not installed by the official user-local installer"
  [[ "$(command -v pi)" == "$launcher" ]] \
    || fail "PATH does not prefer official Pi launcher"
  version="$($launcher --version)"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][[:alnum:].-]+)?$ ]] \
    || fail "invalid Pi version: $version"
  pass "official Pi installation ($version)"
}

verify_npm_tools() {
  local -a items=()
  mapfile -t items < <(collect_manifest_items "npm")
  if ((${#items[@]} == 0)); then
    pass "npm tools (none selected)"
    return 0
  fi

  local expected actual missing npm_root
  expected="$(mktemp)"
  actual="$(mktemp)"
  printf '%s\n' "${items[@]}" >"$expected"
  npm list --global --depth=0 --json \
    | jq -r '.dependencies // {} | to_entries[] | "\(.key)@\(.value.version)"' \
    | LC_ALL=C sort >"$actual"
  missing="$(LC_ALL=C comm -23 "$expected" "$actual")"
  rm -f "$expected" "$actual"
  [[ -z "$missing" ]] || fail "missing npm tools: $missing"

  npm_root="$(npm root --global)"
  if ! node - "$npm_root" <<'NODE' >/dev/null
const root = process.argv[2]
const gemini = `${root}/@google/gemini-cli`
const keytar = require(require.resolve('@github/keytar', { paths: [gemini] }))
if (typeof keytar.getPassword !== 'function') process.exit(1)

const pty = require(require.resolve('node-pty', { paths: [gemini] }))
const child = pty.spawn('/usr/bin/true', [], { name: 'xterm', cols: 80, rows: 24 })
const timeout = setTimeout(() => process.exit(1), 5000)
child.onExit(({ exitCode }) => {
  clearTimeout(timeout)
  process.exit(exitCode)
})
NODE
  then
    fail "Gemini CLI native npm modules are unavailable"
  fi
  pass "npm tools"
}

verify_stow() {
  local directory output
  if ! output="$(
    stow --dir="$DOTFILES" --target="$HOME" --no-folding \
      "${STOW_IGNORE_ARGS[@]}" --simulate --verbose=1 "${MODULES[@]}" 2>&1
  )"; then
    fail "Stow simulation failed:\n$output"
  fi
  output="${output//$'WARNING: in simulation mode so not modifying filesystem.'/}"
  [[ -z "$output" ]] || fail "Stow would modify home directory:\n$output"

  for directory in \
    "$HOME/.config/fcitx5" \
    "$HOME/.config/systemd/user" \
    "$HOME/.config/theme" \
    "$HOME/.config/tt"
  do
    [[ -d "$directory" && ! -L "$directory" ]] \
      || fail "runtime-writable directory must be real: $directory"
  done
  pass "Stow layout"
}

verify_configs() {
  local passwd_line shell unit
  passwd_line="$(getent passwd "$USER")"
  IFS=: read -r _ _ _ _ _ _ shell <<<"$passwd_line"
  [[ "$shell" == /usr/bin/zsh ]] || fail "login shell is not /usr/bin/zsh"

  Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua" >/dev/null \
    || fail "Hyprland Lua config validation failed"
  ghostty +validate-config >/dev/null || fail "Ghostty config validation failed"
  cmp -s "$DOTFILES/nvim/.config/nvim/lazy-lock.json" \
    "$HOME/.config/nvim/lazy-lock.json" \
    || fail "installed Neovim lockfile differs from repository"
  nvim --headless \
    '+lua assert(vim.g.colors_name == "catppuccin-latte" or vim.g.colors_name == "catppuccin-macchiato")' \
    +qa >/dev/null || fail "Neovim headless startup failed"
  cmp -s "$DOTFILES/nvim/.config/nvim/lazy-lock.json" \
    "$HOME/.config/nvim/lazy-lock.json" \
    || fail "Neovim startup modified installed lockfile"
  nvim --headless \
    "+lua for _, language in ipairs(require('core.treesitter_languages')) do assert(pcall(vim.treesitter.language.add, language), 'missing parser: ' .. language) end" \
    +qa >/dev/null || fail "Treesitter parser validation failed"
  for unit in daily-wallpaper.service daily-wallpaper.timer tt.service; do
    cmp -s "$DOTFILES/systemd/.config/systemd/user/$unit" \
      "$HOME/.config/systemd/user/$unit" \
      || fail "installed user unit differs from repository: $unit"
  done
  systemd-analyze --user verify \
    "$HOME/.config/systemd/user/daily-wallpaper.service" \
    "$HOME/.config/systemd/user/daily-wallpaper.timer" \
    "$HOME/.config/systemd/user/tt.service" >/dev/null
  fc-match 'Maple Mono NF CN' | grep -Fq 'MapleMono' \
    || fail "Maple Mono NF CN is not available"
  [[ -d /usr/share/icons/Adwaita/cursors ]] \
    || fail "Adwaita cursor theme is not installed"
  pass "desktop configuration"
}

verify_services() {
  systemctl --user is-enabled daily-wallpaper.timer >/dev/null \
    || fail "daily-wallpaper.timer is not enabled"
  systemctl --user is-active daily-wallpaper.timer >/dev/null \
    || fail "daily-wallpaper.timer is not active"
  if [[ -f "$HOME/.config/tt/schedule.json" ]]; then
    "$HOME/.local/bin/tt" validate >/dev/null || fail "private tt schedule is invalid"
    systemctl --user is-enabled tt.service >/dev/null || fail "tt.service is not enabled"
    systemctl --user is-active tt.service >/dev/null || fail "tt.service is not active"
  fi
  pass "public user services"
}

verify_mime_defaults() {
  [[ "$(xdg-mime query default text/html)" == firefox.desktop ]] \
    || fail "HTML default is not Firefox"
  [[ "$(xdg-mime query default application/pdf)" == org.pwmt.zathura-pdf-mupdf.desktop ]] \
    || fail "PDF default is not Zathura"
  [[ "$(xdg-mime query default text/markdown)" == nvim.desktop ]] \
    || fail "Markdown default is not Neovim"
  [[ "$(xdg-mime query default text/x-bibtex)" == nvim.desktop ]] \
    || fail "BibTeX default is not Neovim"
  pass "MIME defaults"
}

verify_installed() {
  [[ -z "$(git -C "$DOTFILES" status --porcelain)" ]] || fail "dotfiles worktree is dirty"
  verify_pacman_packages
  verify_flatpak_packages
  verify_pi
  verify_npm_tools
  verify_stow
  verify_configs
  verify_services
  verify_mime_defaults
  pass "installed restore state"
}

require_one_process() {
  local process="$1" count
  count="$(pgrep -cx "$process" || true)"
  [[ "$count" == 1 ]] || fail "expected one $process process, found $count"
}

verify_session() {
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || fail "no active Hyprland session"
  [[ -z "$(hyprctl configerrors)" ]] || fail "Hyprland reports configuration errors"
  require_one_process waybar
  require_one_process mako
  require_one_process hyprpaper
  require_one_process fcitx5
  require_one_process udiskie
  [[ "$(pgrep -cx wl-paste || true)" -eq 2 ]] || fail "clipboard watchers are not running exactly twice"
  "$HOME/.local/bin/tt" bar | jq -e 'has("text") and has("tooltip") and has("class")' >/dev/null \
    || fail "tt Waybar output is invalid"
  pass "live Hyprland session"
}

main() {
  parse_args "$@"
  case "$MODE" in
    --repo-only)
      validate_repository
      ;;
    installed)
      validate_repository
      verify_installed
      ;;
    --session)
      validate_repository
      verify_installed
      verify_session
      ;;
  esac
}

main "$@"
