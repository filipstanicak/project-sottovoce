#!/usr/bin/env bash

set -euo pipefail

godot --headless --path . res://tools/generate_default_tuning.tscn
godot --headless --path . -s res://tools/generate_map_vetraio.gd
godot --headless --path . -s res://tools/generate_map_sandbox.gd

if ! git diff --exit-code -- data/ scenes/map/; then
	echo "generated resources are stale; regenerate tuning data and both maps" >&2
	exit 1
fi
untracked=$(git status --porcelain --untracked-files=all -- data/ scenes/map/ | sed -n 's/^?? //p')
if [ -n "$untracked" ]; then
	printf '%s\n' "$untracked" >&2
	echo "the resource generators produced untracked output" >&2
	exit 1
fi

echo "generated resources reproduce the committed tree"
