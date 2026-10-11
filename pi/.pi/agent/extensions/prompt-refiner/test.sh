#!/usr/bin/env bash
# Run the prompt-refiner test suites.
#
# index.ts and loader.ts import pi by package name, exactly as pi loads them at
# runtime, so the tests need those packages resolvable from this directory.
# `node_modules/` holds symlinks into the installed pi and is gitignored, so
# this script recreates them before running the suites.
set -Eeuo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer the official user-local install; fall back to whatever `pi` resolves to.
pi_dir=""
for candidate in \
  "$HOME/.local/lib/node_modules/@earendil-works/pi-coding-agent" \
  "$(command -v pi >/dev/null 2>&1 && readlink -f "$(command -v pi)" | sed -n 's#/dist/.*##p')"; do
  if [[ -n "$candidate" && -d "$candidate" ]]; then
    pi_dir="$candidate"
    break
  fi
done

if [[ -z "$pi_dir" ]]; then
  printf 'could not locate the pi install; install pi or run with pi on PATH\n' >&2
  exit 1
fi

link() {
  local target="$1" name="$2"
  [[ -e "$target" ]] || return 0
  ln -sfn "$target" "$here/node_modules/$name"
}

mkdir -p "$here/node_modules/@earendil-works"
link "$pi_dir/node_modules/@earendil-works/pi-tui" "@earendil-works/pi-tui"
link "$pi_dir/node_modules/@earendil-works/pi-ai" "@earendil-works/pi-ai"
link "$pi_dir" "@earendil-works/pi-coding-agent"

exec node --test "$here"/*.test.ts
