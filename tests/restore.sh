#!/usr/bin/env bash
# No installation or changes to the real package manifests.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/restore.sh"
die() { printf '%s\n' "$*" >&2; exit 1; }
DOTFILES="$(mktemp -d)"
trap 'rm -rf "$DOTFILES"' EXIT
cp -r "$ROOT/pkgs" "$DOTFILES/"

parse_profile_csv ' dev,academic,dev, '
finalize_profiles
[[ "${SELECTED_PROFILES[*]}" == 'academic dev' ]]
FULL_MODE=1
finalize_profiles
[[ ${#SELECTED_PROFILES[@]} -eq ${#KNOWN_PROFILES[@]} ]]
validate_manifest_tree

# Core-only and selected-profile results match the actual input files.
for selection in '' dev; do
  SELECTED_PROFILES=()
  [[ -z "$selection" ]] || SELECTED_PROFILES=("$selection")
  for kind in "${MANIFEST_NAMES[@]}"; do
    paths=("$DOTFILES/pkgs/core/$kind.txt")
    if [[ -n "$selection" && -f "$DOTFILES/pkgs/profiles/$selection/$kind.txt" ]]; then
      paths+=("$DOTFILES/pkgs/profiles/$selection/$kind.txt")
    fi
    diff -u <(LC_ALL=C sort -u "${paths[@]}") <(collect_manifest_items "$kind")
  done
done

if (parse_profile_csv '../dev') 2>/dev/null; then die 'accepted unknown profile'; fi
if (parse_profile_csv '"dev"') 2>/dev/null; then die 'accepted quoted profile'; fi

# Duplicate packages, cross-repository collisions, malformed files and unknown profiles.
for case in duplicate collision unsorted padded missing unknown-profile unknown-kind; do
  rm -rf "$DOTFILES/pkgs"
  cp -r "$ROOT/pkgs" "$DOTFILES/"
  case "$case" in
    duplicate) printf 'git\n' > "$DOTFILES/pkgs/profiles/dev/official.txt" ;;
    collision) printf 'git\n' > "$DOTFILES/pkgs/profiles/dev/aur.txt" ;;
    unsorted) printf 'zsh\ngit\n' > "$DOTFILES/pkgs/core/official.txt" ;;
    padded) printf ' git\n' > "$DOTFILES/pkgs/core/official.txt" ;;
    missing) rm "$DOTFILES/pkgs/core/official.txt" ;;
    unknown-profile) mkdir "$DOTFILES/pkgs/profiles/unknown" ;;
    unknown-kind) touch "$DOTFILES/pkgs/core/unknown.txt" ;;
  esac
  if (validate_manifest_tree) >/dev/null 2>&1; then die "accepted $case"; fi
done
printf 'PASS shared restore contract\n'
