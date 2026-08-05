#!/usr/bin/env bash
#
# Shared file enumeration for the CI guards. SOURCED, never executed.
#
# Why this exists. On 2026-08-05 both `.ci/ip_guard.sh` and
# `.ci/check_asset_inventory.sh` were found to print "clean" and exit 0 having
# scanned ZERO files. Both enumerated with `git ls-files`, which fails outside a
# git work tree — and this project's own checkpoint procedure runs them inside a
# `git archive HEAD | tar -x` extraction, which is not one (CLAUDE.md trap 3,
# `.claude/commands/save.md` §8). git wrote "fatal: not a git repository" to
# stderr, the read loop received nothing, `status` stayed 0, and each guard
# announced success. A planted banned term under `scripts/` and an unlicensed
# file under `assets/` were both waved through.
#
# This is the failure shape `.ci/run_gut.sh` was written for, in a second place:
# THE GREEN WAS THE REAL DEFECT. A guard that scans nothing and reports success
# is worse than a red build, because it is precisely the reason nobody looks
# again — and unlike a red build it never asks to be investigated.
#
# Two fixes, because there were two faults:
#
#   1. Enumeration falls back to `find` when there is no work tree, so the
#      guards actually work where the checkpoint procedure runs them. Verifying
#      from a clean checkout is the documented method; a guard that cannot run
#      there is a guard that is skipped there.
#   2. An empty or implausible enumeration is a HARD FAILURE. This repository
#      tracks hundreds of files. Zero means the scan broke, never that the
#      repository is clean, and the two must never again look alike.
#
# Contract: the caller runs from the repository root, and calls
#
#     repo_files_load "<label>" || exit 1
#
# which populates the REPO_FILES array or explains why it could not.

# Every file in the repository, relative to the root. Populated by
# repo_files_load; do not read it before that call has succeeded.
REPO_FILES=()

# A file that must appear in any correct enumeration of this repository. It is
# how "you ran the guard from the wrong directory" is told apart from "the
# repository is clean" — the second fault above in its other disguise.
REPO_FILES_ANCHOR="project.godot"

# Directories that are derived, never scanned, and absent from an archive
# extraction anyway. Only consulted on the `find` path; `git ls-files` already
# knows they are not tracked.
_repo_files_find() {
	find . -type f \
		-not -path './.git/*' \
		-not -path './.godot/*' \
		-print
}

_repo_files_refuse() {
	local label="$1" reason="$2"
	cat >&2 <<-EOF

		$label: FAILED — $reason

		  A scan that cannot be right must not report success. This tree holds
		  hundreds of files with $REPO_FILES_ANCHOR among them; anything else means
		  the enumeration broke, not that the repository is clean.

		  Run this from the repository root. It works both in a git work tree and in
		  a \`git archive HEAD | tar -x\` extraction, which is where the checkpoint
		  procedure in .claude/commands/save.md §8 runs it.

		  Do NOT relax this check to make the guard quiet. See .ci/run_gut.sh: a
		  green that scanned the wrong thing is the failure mode it exists for.

	EOF
}

# Populates REPO_FILES. Returns 1, loudly, rather than yielding a list that
# cannot be right.
repo_files_load() {
	local label="${1:?repo_files_load needs a label}"
	local source_label raw line found

	REPO_FILES=()

	if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		source_label="git ls-files"
		if ! raw=$(git ls-files); then
			_repo_files_refuse "$label" "git ls-files failed inside a git work tree"
			return 1
		fi
	else
		source_label="find (no git work tree — archive extraction)"
		if ! raw=$(_repo_files_find); then
			_repo_files_refuse "$label" "find failed while enumerating the tree"
			return 1
		fi
	fi

	# The repo is developed on Windows and CI runs on Linux, so strip a trailing
	# CR from every path. Without it an exclusion matches on one platform and not
	# the other — worse than no exclusion, because it fails asymmetrically.
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line%$'\r'}"
		line="${line#./}"
		[ -n "$line" ] || continue
		REPO_FILES+=("$line")
	done <<<"$raw"

	if [ "${#REPO_FILES[@]}" -eq 0 ]; then
		_repo_files_refuse "$label" "the scan enumerated ZERO files ($source_label)"
		return 1
	fi

	found=1
	for line in "${REPO_FILES[@]}"; do
		if [ "$line" = "$REPO_FILES_ANCHOR" ]; then
			found=0
			break
		fi
	done
	if [ "$found" -ne 0 ]; then
		_repo_files_refuse \
			"$label" \
			"the scan found ${#REPO_FILES[@]} file(s) but not $REPO_FILES_ANCHOR — wrong directory?"
		return 1
	fi

	echo "$label: scanning ${#REPO_FILES[@]} file(s) via $source_label"
}
