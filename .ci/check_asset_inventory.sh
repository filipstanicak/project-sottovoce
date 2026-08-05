#!/usr/bin/env bash
# Asset licence inventory — see docs/00_meta/ASSET_LICENSES.md §5
#
# Checked in BOTH directions. A stale row is as much a defect as a missing
# one: it means someone deleted an asset and left a claim about it, which
# makes the whole register untrustworthy.
#
# The file list comes from .ci/repo_files.sh, which REFUSES to hand back an
# empty one. This check used to enumerate with a bare `git ls-files ... || true`
# and so reported "clean" over zero files in an archive extraction, where an
# unlicensed asset passed — read that script's header before changing anything
# here.
#
# Note the asymmetry: an empty *repository* scan is always a broken scan, but an
# empty *asset* list is legitimate — today every path under assets/ is a
# .gdkeep. So the emptiness check belongs to the whole-tree enumeration, and
# only there.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=repo_files.sh
. "$HERE/repo_files.sh"

REGISTER="docs/00_meta/ASSET_LICENSES.md"
status=0

# Authored in-repo, licence-exempt. Extending this list requires an ADR.
is_exempt() {
  case "$1" in
    assets/greybox/*|assets/procedural/*) return 0 ;;
    *) return 1 ;;
  esac
}

repo_files_load "asset-inventory" || exit 1

# Assets present in the repo
present=()
for f in "${REPO_FILES[@]}"; do
  case "$f" in
    assets/*|data/fonts/*) ;;
    *) continue ;;
  esac
  case "$f" in */.gdkeep) continue ;; esac
  present+=("$f")
done

# Paths claimed by the register (any assets/... or data/fonts/... in a table cell)
claimed=$(grep -oE '(assets|data/fonts)/[A-Za-z0-9_./-]+' "$REGISTER" 2>/dev/null | sort -u || true)

for f in "${present[@]+"${present[@]}"}"; do
  is_exempt "$f" && continue
  if ! echo "$claimed" | grep -qx "$f"; then
    echo "MISSING LICENCE ROW: $f"
    status=1
  fi
done

for c in $claimed; do
  case "$c" in assets/greybox/*|assets/procedural/*) continue ;; esac
  if [ ! -e "$c" ]; then
    echo "STALE REGISTER ROW: $c (no such file)"
    status=1
  fi
done

[ "$status" -eq 0 ] && echo "asset-inventory: clean"
exit "$status"
