#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIN_FILE="$ROOT/.godot-version"
DIGEST_FILE="$ROOT/.ci/godot_downloads.sha256"

if [ ! -f "$PIN_FILE" ]; then
	echo "resolve_godot_pin: missing .godot-version" >&2
	exit 1
fi

GODOT_FULL="$(tr -d '[:space:]' < "$PIN_FILE")"
if [[ ! "$GODOT_FULL" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.stable\.official\.([0-9a-f]{9})$ ]]; then
	echo "resolve_godot_pin: malformed pin: $GODOT_FULL" >&2
	exit 1
fi

GODOT_SEMVER="${BASH_REMATCH[1]}"
GODOT_TAG="${GODOT_SEMVER}-stable"
GODOT_ARCHIVE="Godot_v${GODOT_TAG}_linux.x86_64.zip"

mapfile -t matches < <(awk -v archive="$GODOT_ARCHIVE" '$2 == archive {print $1}' "$DIGEST_FILE")
if [ "${#matches[@]}" -ne 1 ] || [[ ! "${matches[0]:-}" =~ ^[0-9a-f]{64}$ ]]; then
	echo "resolve_godot_pin: expected exactly one SHA-256 for $GODOT_ARCHIVE" >&2
	exit 1
fi
GODOT_SHA256="${matches[0]}"

printf 'GODOT_FULL=%q\n' "$GODOT_FULL"
printf 'GODOT_SEMVER=%q\n' "$GODOT_SEMVER"
printf 'GODOT_TAG=%q\n' "$GODOT_TAG"
printf 'GODOT_ARCHIVE=%q\n' "$GODOT_ARCHIVE"
printf 'GODOT_SHA256=%q\n' "$GODOT_SHA256"
