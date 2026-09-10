# Shared restore contract. Callers provide DOTFILES and die().
MODULES=(
  hyprland waybar rofi ghostty nvim yazi tmux zsh
  fcitx5 ripgrep vscode xdg scripts tt pi
)
STOW_IGNORE_ARGS=(
  --ignore='(^|/)auth\.json$'
  --ignore='(^|/)node_modules($|/)'
  --ignore='(^|/)__pycache__($|/)'
  --ignore='\.py[cod]$'
  --ignore='(^|/)host\.lua$'
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

is_valid_profile() {
  local candidate="$1" item
  for item in "${KNOWN_PROFILES[@]}"; do
    [[ "$candidate" == "$item" ]] && return 0
  done
  return 1
}

parse_profile_csv() {
  local csv="$1" profile
  local -a raw_profiles=()
  IFS=',' read -r -a raw_profiles <<<"$csv"
  for profile in "${raw_profiles[@]}"; do
    profile="${profile#"${profile%%[![:space:]]*}"}"
    profile="${profile%"${profile##*[![:space:]]}"}"
    [[ -n "$profile" ]] || continue
    is_valid_profile "$profile" \
      || die "unknown profile: $profile (valid: ${KNOWN_PROFILES[*]})"
    SELECTED_PROFILES+=("$profile")
  done
}

finalize_profiles() {
  if [[ $FULL_MODE -eq 1 ]]; then
    SELECTED_PROFILES=("${KNOWN_PROFILES[@]}")
  fi
  if ((${#SELECTED_PROFILES[@]} > 0)); then
    mapfile -t SELECTED_PROFILES < <(printf '%s\n' "${SELECTED_PROFILES[@]}" | LC_ALL=C sort -u)
  fi
}

collect_manifest_items() {
  local manifest_name="$1" item path profile
  local -a items=()
  for profile in core "${SELECTED_PROFILES[@]/#/profiles/}"; do
    path="$DOTFILES/pkgs/$profile/$manifest_name.txt"
    [[ -f "$path" ]] || continue
    while IFS= read -r item || [[ -n "$item" ]]; do
      [[ -n "$item" ]] && items+=("$item")
    done <"$path"
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
    validate_manifest_file "$DOTFILES/pkgs/core/$name.txt"
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
