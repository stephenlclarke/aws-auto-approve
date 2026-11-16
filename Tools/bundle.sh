#!/usr/bin/env bash
# USAGE: bundle.sh [--help]
set -euo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
    printf 'Usage: %s [--help]\nBuild the app bundle after make build-release.\n' "$(basename "$0")"
    exit 0
fi
if [[ $# -ne 0 ]]; then exit 2; fi
APP_VERSION="${APP_VERSION:-0.0.0}"
[[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'APP_VERSION must be a stable semantic version.\n' >&2; exit 2; }
if [[ -n "${BUILD_ARCH:-}" ]]; then
    BIN_DIR="$("${SWIFT:-$(xcrun --toolchain XcodeDefault --find swift)}" build --disable-sandbox -c release --arch "$BUILD_ARCH" --show-bin-path)"
else
    BIN_DIR=.build/release
fi
bash Tools/build-icon.sh
APP='dist/AWS Auto Approve.app'
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/AppIcon.icns "$APP/Contents/Resources/"
cp "$BIN_DIR/aws-auto-approve" "$APP/Contents/MacOS/"
cp -R "$BIN_DIR/AWSAutoApprove_ApprovalCore.bundle" "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.stephenlclarke.aws-auto-approve</string>
<key>CFBundleName</key><string>AWS Auto Approve</string>
<key>CFBundleExecutable</key><string>aws-auto-approve</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_VERSION" "$APP/Contents/Info.plist"
signing_identity="${CODESIGN_IDENTITY:--}"
signing_args=(--force --sign "$signing_identity")
if [[ "$signing_identity" != - ]]; then
    signing_args+=(--options runtime --timestamp)
    if [[ -n "${CODESIGN_KEYCHAIN:-}" ]]; then signing_args+=(--keychain "$CODESIGN_KEYCHAIN"); fi
fi
codesign "${signing_args[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [[ "${BUILD_ARCH:-$(uname -m)}" == "$(uname -m)" ]]; then
    "$APP/Contents/MacOS/aws-auto-approve" --help >/dev/null
fi
if [[ "$signing_identity" == - ]]; then
    printf 'Built %s (local ad-hoc signature).\n' "$APP"
else
    printf 'Built %s (Developer ID signature).\n' "$APP"
fi
