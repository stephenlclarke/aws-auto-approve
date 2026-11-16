#!/usr/bin/env bash
# USAGE:
#   Usage: @SCRIPT_NAME@ APP | --check | --help
#
# DESCRIPTION:
#   Submit a Developer ID-signed app to Apple, inspect its result and staple
#   its accepted ticket. Stop publication if any verification fails.
#
# ENVIRONMENT:
#   CODESIGN_IDENTITY       Developer ID Application identity, never '-'.
#   APPLE_TEAM_ID           Expected ten-character signing team.
#   NOTARY_KEYCHAIN_PROFILE Local notarytool credentials profile, or supply:
#   APPLE_NOTARY_KEY_PATH   Private App Store Connect team API key file.
#   APPLE_NOTARY_KEY_ID     API key identifier.
#   APPLE_NOTARY_ISSUER_ID  API key issuer identifier.
# ENDUSAGE
set -euo pipefail
readonly SELF_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_NAME="$(basename "$SELF_PATH")"
readonly SCRIPT_NAME
WORK_DIR=''

# Print help without exposing the environment.
usage() {
    awk -v name="$SCRIPT_NAME" '/^# USAGE:/ {p=1;next} p && /^# ENDUSAGE/ {exit} p {sub(/^# ?/, "");gsub(/@SCRIPT_NAME@/,name);print}' "$SELF_PATH"
}

# Stop before rejected or unstapled software can be packaged.
error() { printf '[x] %s\n' "$*" >&2; exit 1; }

# Remove only this invocation's archive and service responses.
cleanup() { if [[ -n "$WORK_DIR" ]]; then rm -rf "$WORK_DIR"; fi; }

# Check configuration before building; signing and service checks follow.
check_credentials() {
    [[ -n "${CODESIGN_IDENTITY:-}" && "$CODESIGN_IDENTITY" != - ]] || error 'A Developer ID Application signing identity is required.'
    [[ "${APPLE_TEAM_ID:-}" =~ ^[A-Z0-9]{10}$ ]] || error 'APPLE_TEAM_ID must identify the signing team.'
    if [[ -z "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
        [[ -f "${APPLE_NOTARY_KEY_PATH:-}" && -n "${APPLE_NOTARY_KEY_ID:-}" && -n "${APPLE_NOTARY_ISSUER_ID:-}" ]] || error 'Configure a notarytool Keychain profile or App Store Connect team API key.'
    fi
}

# Notarise exactly this signed app and verify the attached distribution ticket.
main() {
    local app="${1:-}" submission
    local -a auth
    if [[ "$app" == --help || "$app" == -h ]]; then usage; return; fi
    [[ $# == 1 ]] || { usage >&2; return 2; }
    check_credentials
    if [[ "$app" == --check ]]; then return; fi
    [[ -d "$app/Contents/MacOS" ]] || error 'Supply an app bundle.'
    WORK_DIR="$(mktemp -d)"
    trap cleanup EXIT
    codesign --verify --deep --strict "$app"
    codesign --display --verbose=4 "$app" 2>"$WORK_DIR/signature"
    grep -Fq 'Authority=Developer ID Application:' "$WORK_DIR/signature" || error 'The app does not have a Developer ID Application signature.'
    grep -Fxq "TeamIdentifier=$APPLE_TEAM_ID" "$WORK_DIR/signature" || error 'The app belongs to a different signing team.'
    grep -Eq 'flags=.*runtime' "$WORK_DIR/signature" || error 'Hardened Runtime is missing.'
    grep -q '^Timestamp=' "$WORK_DIR/signature" || error 'A secure signing timestamp is missing.'
    if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
        auth=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
    else
        auth=(--key "$APPLE_NOTARY_KEY_PATH" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID")
    fi
    ditto -c -k --keepParent "$app" "$WORK_DIR/app.zip"
    xcrun notarytool submit "$WORK_DIR/app.zip" "${auth[@]}" --wait --timeout 30m --output-format json >"$WORK_DIR/result.json"
    jq -e '.status == "Accepted"' "$WORK_DIR/result.json" >/dev/null || error 'Apple did not accept the notarisation submission.'
    submission="$(jq -er '.id | select(type == "string" and test("^[A-Fa-f0-9-]{36}$"))' "$WORK_DIR/result.json")"
    xcrun notarytool log "$submission" "${auth[@]}" "$WORK_DIR/log.json" >/dev/null
    jq -e '.status == "Accepted" and ([.issues[]? | select(.severity == "error")] | length == 0)' "$WORK_DIR/log.json" >/dev/null || error 'Apple reported a notarisation error.'
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
    codesign --verify --deep --strict "$app"
    spctl --assess --type execute "$app"
    printf '[v] Apple notarisation accepted; ticket stapled and verified.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
