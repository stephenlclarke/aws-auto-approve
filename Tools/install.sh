#!/usr/bin/env bash
# USAGE: install.sh [--help]
set -euo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
    printf 'Usage: %s [--help]\nInstall in ~/Applications and ~/.local/bin. Granted settings stay unchanged.\n' "$(basename "$0")"
    exit 0
fi
if [[ $# -ne 0 ]]; then exit 2; fi
DEST="$HOME/Applications/AWS Auto Approve.app"
LINK="$HOME/.local/bin/aws-auto-approve"
if [[ -e "$DEST" || -e "$LINK" || -L "$LINK" ]]; then
    printf 'An installation already exists. Move it aside before installing.\n' >&2
    exit 1
fi
mkdir -p "$HOME/Applications" "$HOME/.local/bin"
cp -R 'dist/AWS Auto Approve.app' "$DEST"
ln -s "$DEST/Contents/MacOS/aws-auto-approve" "$LINK"
printf 'Installed %s\nGranted settings stay unchanged. See README.md for setup.\n' "$LINK"
