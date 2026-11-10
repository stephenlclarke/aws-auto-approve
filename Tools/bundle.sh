#!/usr/bin/env bash
# USAGE: bundle.sh [--help]
set -euo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
    printf 'Usage: %s [--help]\nBuild the app bundle after make build-release.\n' "$(basename "$0")"
    exit 0
fi
if [[ $# -ne 0 ]]; then exit 2; fi
APP='dist/AWS Auto Approve.app'
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/aws-auto-approve "$APP/Contents/MacOS/"
cp -R .build/release/AWSAutoApprove_ApprovalCore.bundle "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.stephenlclarke.aws-auto-approve</string>
<key>CFBundleName</key><string>AWS Auto Approve</string>
<key>CFBundleExecutable</key><string>aws-auto-approve</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/aws-auto-approve" --help >/dev/null
printf 'Built %s (local ad-hoc signature).\n' "$APP"
