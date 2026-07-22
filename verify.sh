#!/usr/bin/env bash
# Verify repository integrity, installed state, and optionally the live Hyprland session.
set -Eeuo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-installed}"
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

pass() { printf '\e[32mPASS\e[0m %s\n' "$*"; }
fail() { printf '\e[31mFAIL\e[0m %s\n' "$*" >&2; exit 1; }

validate_manifests() {
  local name path overlap
  for name in "${MANIFESTS[@]}"; do
    path="$DOTFILES/pkgs/$name.txt"
    [[ -s "$path" ]] || fail "missing manifest: $path"
    LC_ALL=C sort -cu "$path" || fail "manifest is not sorted and unique: $path"
    ! grep -q '^$' "$path" || fail "blank line in manifest: $path"
  done

  overlap="$(LC_ALL=C comm -12 "$DOTFILES/pkgs/official.txt" "$DOTFILES/pkgs/aur.txt")"
  [[ -z "$overlap" ]] || fail "official/AUR overlap: $overlap"
  pass "package manifests"
}

validate_scripts() {
  bash -n "$DOTFILES/bootstrap.sh" "$DOTFILES/verify.sh"
  bash -n "$DOTFILES/scripts/.local/bin/theme-switch"
  bash -n "$DOTFILES/scripts/.local/bin/daily-wallpaper.sh"
  sh -n "$DOTFILES/hyprland/.config/hypr/scripts/away-lock.sh"
  sh -n "$DOTFILES/hyprland/.config/hypr/scripts/layout-dispatch.sh"
  sh -n "$DOTFILES/hyprland/.config/hypr/scripts/quicknote.sh"

  local cache
  cache="$(mktemp -d)"
  PYTHONPYCACHEPREFIX="$cache" python -m py_compile \
    "$DOTFILES/tt/.local/bin/tt" \
    "$DOTFILES/nvim/.config/nvim/bin/render_markdown_latex.py"
  rm -rf "$cache"
  pass "script syntax"
}

validate_data_files() {
  jq empty "$DOTFILES/vscode/.config/Code/User/settings.json"
  jq empty "$DOTFILES/tt/.config/tt/schedule.example.json"
  jq empty "$DOTFILES/waybar/.config/waybar/config.jsonc"
  pass "JSON and JSONC files"
}

validate_stow_sources() {
  local module path relative
  local -a unsafe=()
  for module in "${MODULES[@]}"; do
    while IFS= read -r -d '' path; do
      relative="${path#"$DOTFILES/"}"
      case "$relative" in
        */.claude/*|*/__pycache__/*|*.pyc|*.pyo|*/host.conf|*/schedule.json|*/subscription.env|*/installation.yaml|*/user.yaml|*.userdb/*|*/sync/*|*/generated/*|*.key|*.pem|*.p12|*.pfx|*.log)
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
        */subscription.env|*/schedule.json|*/host.conf|*/installation.yaml|*/user.yaml|*.userdb/*|*/sync/*|*/generated/*|*/.claude/*|*.key|*.pem|*.p12|*.pfx|*.log)
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
  validate_stow_sources
  validate_public_boundary
}

manifest_items() {
  mapfile -t ITEMS <"$1"
}

verify_pacman_packages() {
  local missing
  manifest_items "$DOTFILES/pkgs/official.txt"
  if ! missing="$(pacman -T "${ITEMS[@]}")"; then
    fail "missing official packages: $missing"
  fi
  manifest_items "$DOTFILES/pkgs/aur.txt"
  if ! missing="$(pacman -T "${ITEMS[@]}")"; then
    fail "missing AUR packages: $missing"
  fi
  pass "Pacman and AUR packages"
}

verify_flatpak_packages() {
  local app
  while IFS= read -r app; do
    flatpak info --system "$app" >/dev/null || fail "missing Flatpak application: $app"
  done <"$DOTFILES/pkgs/flatpak.txt"
  pass "Flatpak applications"
}

verify_npm_tools() {
  local expected actual missing npm_root
  expected="$(mktemp)"
  actual="$(mktemp)"
  cp "$DOTFILES/pkgs/npm.txt" "$expected"
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

verify_uv_tools() {
  local spec package version output
  output="$(uv tool list)"
  while IFS= read -r spec; do
    package="${spec%%==*}"
    version="${spec#*==}"
    grep -Fqx "$package v$version" <<<"$output" \
      || fail "missing uv tool: $spec"
  done <"$DOTFILES/pkgs/uv.txt"
  pass "uv tools"
}

verify_vscode_extensions() {
  local expected actual missing
  expected="$(mktemp)"
  actual="$(mktemp)"
  cp "$DOTFILES/pkgs/vscode-extensions.txt" "$expected"
  code --list-extensions --show-versions | LC_ALL=C sort >"$actual"
  missing="$(LC_ALL=C comm -23 "$expected" "$actual")"
  rm -f "$expected" "$actual"
  [[ -z "$missing" ]] || fail "missing VS Code extensions: $missing"
  pass "VS Code extensions"
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
  [[ -z "$output" ]] || fail "Stow would modify the home directory:\n$output"

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

  Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.conf" >/dev/null \
    || fail "Hyprland config validation failed"
  ghostty +validate-config >/dev/null || fail "Ghostty config validation failed"
  cmp -s "$DOTFILES/nvim/.config/nvim/lazy-lock.json" \
    "$HOME/.config/nvim/lazy-lock.json" \
    || fail "installed Neovim lockfile differs from repository"
  nvim --headless \
    '+lua assert(vim.g.colors_name == "catppuccin-latte" or vim.g.colors_name == "catppuccin-macchiato")' \
    +qa >/dev/null || fail "Neovim headless startup failed"
  cmp -s "$DOTFILES/nvim/.config/nvim/lazy-lock.json" \
    "$HOME/.config/nvim/lazy-lock.json" \
    || fail "Neovim startup modified the installed lockfile"
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
  [[ "$(xdg-mime query default text/markdown)" == marktext.desktop ]] \
    || fail "Markdown default is not MarkText"
  [[ "$(xdg-mime query default x-scheme-handler/clash)" == clash-verge-handler.desktop ]] \
    || fail "clash URL handler is not restored"
  [[ "$(xdg-mime query default x-scheme-handler/clash-verge)" == clash-verge-handler.desktop ]] \
    || fail "clash-verge URL handler is not restored"
  pass "MIME defaults"
}

verify_installed() {
  [[ -z "$(git -C "$DOTFILES" status --porcelain)" ]] || fail "dotfiles worktree is dirty"
  verify_pacman_packages
  verify_flatpak_packages
  verify_npm_tools
  verify_uv_tools
  verify_vscode_extensions
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
  *)
    fail "usage: verify.sh [--repo-only|--session]"
    ;;
esac
