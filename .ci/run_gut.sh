#!/usr/bin/env bash
#
# Run a GUT suite and REFUSE TO PASS IF IT SILENTLY RAN THE WRONG NUMBER OF FILES.
#
# Why this exists. On 2026-08-04 CI reported "All tests passed" for a commit whose
# three new architecture guards never executed. The import cache key hashed only
# project.godot and **/*.import, so adding .gd files did not change it; the
# `import` job got a cache hit and therefore never saved its fresh result, and
# `test` restored a .godot whose script registry predated the new files. Godot
# lists only files it has imported, so GUT scanned the directory, found six
# scripts instead of nine, ran them, and exited 0.
#
# The cache key is fixed. This check exists because THE GREEN WAS THE REAL
# DEFECT: a suite that runs the wrong tests and reports success is worse than a
# red build, and nothing in GUT's exit code can tell the difference.

set -euo pipefail

DIR="${1:?usage: run_gut.sh <test dir under res://>}"
LABEL="${2:-$DIR}"

if [ ! -d "$DIR" ]; then
	echo "run_gut: $DIR does not exist — skipping"
	exit 0
fi

expected=$(find "$DIR" -name 'test_*.gd' | wc -l | tr -d '[:space:]')
if [ "$expected" -eq 0 ]; then
	echo "run_gut: no test_*.gd in $DIR yet — skipping"
	exit 0
fi

echo "run_gut: $LABEL — expecting $expected script(s)"

out=$(godot --headless -s addons/gut/gut_cmdln.gd "-gdir=res://$DIR" -gexit 2>&1) || {
	echo "$out"
	echo "run_gut: FAILED — GUT exited non-zero"
	exit 1
}
echo "$out"

# Strip ANSI before parsing; GUT colours its summary.
actual=$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g' \
	| grep -E '^Scripts +[0-9]+' | tail -1 | grep -oE '[0-9]+' || true)

if [ -z "$actual" ]; then
	echo "run_gut: FAILED — could not find the script count in GUT's summary"
	exit 1
fi

if [ "$actual" -ne "$expected" ]; then
	cat >&2 <<-EOF

		run_gut: FAILED — $LABEL ran $actual script(s), but $expected exist on disk.

		  The suite passed while skipping $((expected - actual)) file(s). That is a
		  stale import cache, not a healthy build. Do NOT relax this check: a green
		  that runs the wrong tests is the failure mode it was written for.

	EOF
	exit 1
fi

echo "run_gut: $LABEL ran all $expected script(s)"
