#!/usr/bin/env bash

set -euo pipefail

python tools/tuning_codegen/run_all.py
gdformat scripts/

if ! git diff --exit-code -- scripts/ tools/tuning_codegen/; then
	echo "generated GDScript is stale; run the tuning code generator and gdformat" >&2
	exit 1
fi
untracked=$(git status --porcelain --untracked-files=all -- scripts/ tools/tuning_codegen/ \
	| sed -n 's/^?? //p')
if [ -n "$untracked" ]; then
	printf '%s\n' "$untracked" >&2
	echo "the code generator produced untracked output" >&2
	exit 1
fi

echo "generated GDScript reproduces the committed tree"
