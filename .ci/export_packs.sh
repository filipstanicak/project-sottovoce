#!/usr/bin/env bash

set -euo pipefail

OUT="${1:-.godot/ci-export}"
mkdir -p "$OUT"

godot --headless --quiet --path . --export-pack "Server (Linux headless)" "$OUT/server.pck"
godot --headless --quiet --path . --export-pack "Client (Windows release)" "$OUT/client-windows.pck"
godot --headless --quiet --path . --export-pack "Client (Linux release)" "$OUT/client-linux.pck"

for pack in server.pck client-windows.pck client-linux.pck; do
	if [ ! -s "$OUT/$pack" ]; then
		echo "export_packs: missing or empty $OUT/$pack" >&2
		exit 1
	fi
	if grep -aFq '.mcp.json' "$OUT/$pack"; then
		echo "export_packs: local MCP configuration leaked into $pack" >&2
		exit 1
	fi
done

# A PCK export needs no 1.2 GB platform template and still exercises the preset's
# complete inclusion graph. Booting the server pack proves the stripped topology
# reaches its actual entry point rather than merely producing an archive.
godot --headless --path . --main-pack "$OUT/server.pck" --quit-after 30 -- \
	--server --port 27999 --min-players 1

echo "three release packs exported; stripped server pack booted successfully"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	{
		echo "### Release PCK smoke test"
		for pack in server.pck client-windows.pck client-linux.pck; do
			printf -- '- `%s`: %s bytes\n' "$pack" "$(wc -c < "$OUT/$pack" | tr -d '[:space:]')"
		done
		echo "- stripped server pack booted for 30 frames"
	} >> "$GITHUB_STEP_SUMMARY"
fi
