#!/usr/bin/env bash
# USAGE:
#   Usage: @SCRIPT_NAME@ VERSION
#
# DESCRIPTION:
#   Build signed macOS arm64 and x86_64 release archives and their Homebrew formula.
#   Requires full Xcode. Output is written under dist/release.
#
# OPTIONS:
#   -h, --help    Show this help text and exit.
# ENDUSAGE

set -euo pipefail
readonly SELF_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_NAME="$(basename "$SELF_PATH")"
readonly SCRIPT_NAME
STAGE_DIR=''

# Remove this invocation's staging directory on success, failure or cancellation.
cleanup() {
    if [[ -n "$STAGE_DIR" ]]; then rm -rf "$STAGE_DIR"; fi
}

# Print embedded usage.
usage() {
    awk -v name="$SCRIPT_NAME" '/^# USAGE:/ {p=1;next} p && /^# ENDUSAGE/ {exit} p {sub(/^# ?/, "");gsub(/@SCRIPT_NAME@/,name);print}' "$SELF_PATH"
}

# Build each architecture independently and include the existing shell integration.
main() {
    local version="${1:-}" arch archive minimum
    if [[ "$version" == --help || "$version" == -h ]]; then usage; return; fi
    if [[ $# != 1 || ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then usage >&2; return 2; fi
    bash Tools/notarise.sh --check
    mkdir -p dist/release
    STAGE_DIR="$(mktemp -d)"
    trap cleanup EXIT
    for arch in arm64 x86_64; do
        make bundle BUILD_ARCH="$arch" APP_VERSION="$version"
        [[ "$(lipo -archs 'dist/AWS Auto Approve.app/Contents/MacOS/aws-auto-approve')" == "$arch" ]]
        minimum="$(otool -l 'dist/AWS Auto Approve.app/Contents/MacOS/aws-auto-approve' | awk '/LC_BUILD_VERSION/{p=1} p && /minos/ {print $2;exit}')"
        [[ "$minimum" == 14.0 ]]
        codesign --verify --deep --strict 'dist/AWS Auto Approve.app'
        bash Tools/notarise.sh 'dist/AWS Auto Approve.app'
        rm -rf "$STAGE_DIR/package"
        mkdir "$STAGE_DIR/package"
        cp -R 'dist/AWS Auto Approve.app' Integration Completions LICENSE "$STAGE_DIR/package/"
        archive="aws-auto-approve-$version-macos-$arch.tar.gz"
        COPYFILE_DISABLE=1 tar -czf "dist/release/$archive" -C "$STAGE_DIR/package" .
        mkdir "$STAGE_DIR/verify"
        tar -xzf "dist/release/$archive" -C "$STAGE_DIR/verify"
        xcrun stapler validate "$STAGE_DIR/verify/AWS Auto Approve.app"
        codesign --verify --deep --strict "$STAGE_DIR/verify/AWS Auto Approve.app"
        rm -rf "$STAGE_DIR/verify"
    done
    ruby Tools/render-formula.rb "$version" >dist/release/aws-auto-approve.rb
    ruby -c dist/release/aws-auto-approve.rb
    (cd dist/release && shasum -a 256 "aws-auto-approve-$version-macos-arm64.tar.gz" "aws-auto-approve-$version-macos-x86_64.tar.gz" aws-auto-approve.rb >SHA256SUMS)
    printf 'Prepared release %s for arm64 and x86_64.\n' "$version"
}

main "$@"
