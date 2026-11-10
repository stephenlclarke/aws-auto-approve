#!/usr/bin/env bash
# USAGE: build-icon.sh [--help]
set -euo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
    printf 'Usage: %s [--help]\nGenerate the macOS icon from Resources/AppIcon.png.\n' "$(basename "$0")"
    exit 0
fi
if [[ $# -ne 0 ]]; then exit 2; fi
ICONSET='.build/AppIcon.iconset'
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -s format png -z "$doubled" "$doubled" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns "$ICONSET" --output .build/AppIcon.icns
