#!/usr/bin/env bash
# Asset licence inventory — see docs/00_meta/ASSET_LICENSES.md §5
#
# Checked in BOTH directions. A stale row is as much a defect as a missing
# one: it means someone deleted an asset and left a claim about it, which
# makes the whole register untrustworthy.
set -uo pipefail

REGISTER="docs/00_meta/ASSET_LICENSES.md"
status=0

# Authored in-repo, licence-exempt. Extending this list requires an ADR.
is_exempt() {
  case "$1" in
    assets/greybox/*|assets/procedural/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Assets present in the repo
present=$(git ls-files 'assets/**' 'data/fonts/**' 2>/dev/null | grep -v '/\.gdkeep$' || true)

# Paths claimed by the register (any assets/... or data/fonts/... in a table cell)
claimed=$(grep -oE '(assets|data/fonts)/[A-Za-z0-9_./-]+' "$REGISTER" 2>/dev/null | sort -u || true)

for f in $present; do
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
