#!/usr/bin/env bash
# IP guard — see docs/00_meta/IP_GUARDRAILS.md §6.1
#
# HARD FAILURE, not a warning. Scans file contents AND paths, case-insensitively.
#
# Renaming later does not work: names leak into commit history, asset filenames,
# screenshots, build artefacts and playtester vocabulary, and the cost of a
# rename grows superlinearly.
#
# EXACTLY TWO files are exempt, because they necessarily contain the terms.
# Adding a third requires an ADR (IP_GUARDRAILS §6.1).
#
# Note on line endings: the repo is developed on Windows and CI runs on Linux,
# so every value read from a file is stripped of a trailing CR. Without that an
# exclusion silently fails to match on one platform and not the other — worse
# than no exclusion, because it fails asymmetrically.
#
# The file list comes from .ci/repo_files.sh, which REFUSES to hand back an
# empty one. This guard used to enumerate with a bare `git ls-files` and so
# reported "clean" over zero files in an archive extraction — read that script's
# header before changing anything here.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=repo_files.sh
. "$HERE/repo_files.sh"

TERMS=".ci/banned_terms.txt"
EXCLUDE=".ci/ip_guard_exclude.txt"
status=0

repo_files_load "ip-guard" || exit 1

exclusions=()
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [ -n "$line" ] && exclusions+=("$line")
done < "$EXCLUDE"

is_excluded() {
  local candidate="$1" ex
  for ex in "${exclusions[@]}"; do
    [ "$candidate" = "$ex" ] && return 0
  done
  return 1
}

# --- file contents -----------------------------------------------------------
for path in "${REPO_FILES[@]}"; do
  [ -f "$path" ] || continue
  is_excluded "$path" && continue

  if hits=$(grep -nIi -f "$TERMS" -- "$path" 2>/dev/null); then
    echo "IP GUARD FAILURE in $path"
    echo "$hits" | sed 's/^/    /'
    status=1
  fi
done

# --- paths themselves --------------------------------------------------------
# A banned term in a filename or directory name is as bad as one in a file.
for path in "${REPO_FILES[@]}"; do
  is_excluded "$path" && continue
  if printf '%s' "$path" | grep -qi -f "$TERMS" 2>/dev/null; then
    echo "IP GUARD FAILURE: banned term in path: $path"
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  echo "ip-guard: clean"
else
  echo ""
  echo "Then answer the review question in docs/00_meta/IP_GUARDRAILS.md section 5."
fi
exit "$status"
