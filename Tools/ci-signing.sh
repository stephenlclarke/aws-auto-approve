#!/usr/bin/env bash
# USAGE:
#   Usage: @SCRIPT_NAME@ setup | cleanup | --help
#
# DESCRIPTION:
#   Import release credentials into an isolated GitHub-hosted runner keychain.
#   Keep private material out of logs; remove it in always-run cleanup.
#
# ENVIRONMENT:
#   RUNNER_TEMP, GITHUB_ENV            GitHub Actions runner paths.
#   MACOS_CERTIFICATE_P12              Base64 Developer ID identity export.
#   MACOS_CERTIFICATE_PASSWORD         Password protecting that export.
#   APPLE_NOTARY_KEY_P8                App Store Connect team API private key.
# ENDUSAGE
set -euo pipefail
readonly SELF_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_NAME="$(basename "$SELF_PATH")"
readonly SCRIPT_NAME

# Print help without printing credential values.
usage() {
    awk -v name="$SCRIPT_NAME" '/^# USAGE:/ {p=1;next} p && /^# ENDUSAGE/ {exit} p {sub(/^# ?/, "");gsub(/@SCRIPT_NAME@/,name);print}' "$SELF_PATH"
}

# Import one identity into a temporary keychain, without changing the search list.
setup() {
    local directory="$1" password identity
    [[ -n "${GITHUB_ENV:-}" && -n "${MACOS_CERTIFICATE_P12:-}" && -n "${MACOS_CERTIFICATE_PASSWORD:-}" && -n "${APPLE_NOTARY_KEY_P8:-}" ]] || { printf '[x] Release signing secrets are missing.\n' >&2; return 1; }
    umask 077
    mkdir "$directory"
    printf '%s' "$MACOS_CERTIFICATE_P12" | base64 --decode >"$directory/identity.p12"
    printf '%s' "$APPLE_NOTARY_KEY_P8" >"$directory/notary.p8"
    password="$(openssl rand -base64 32)"
    security create-keychain -p "$password" "$directory/signing.keychain-db"
    security set-keychain-settings -lut 21600 "$directory/signing.keychain-db"
    security unlock-keychain -p "$password" "$directory/signing.keychain-db"
    security import "$directory/identity.p12" -k "$directory/signing.keychain-db" -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign >/dev/null
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$directory/signing.keychain-db" >/dev/null
    identity="$(security find-identity -v -p codesigning "$directory/signing.keychain-db" | awk '/"Developer ID Application:/ {print $2}')"
    [[ "$identity" =~ ^[A-Fa-f0-9]{40}$ ]] || { printf '[x] The export must contain one valid Developer ID Application identity.\n' >&2; return 1; }
    printf 'CODESIGN_IDENTITY=%s\nCODESIGN_KEYCHAIN=%s\nAPPLE_NOTARY_KEY_PATH=%s\n' "$identity" "$directory/signing.keychain-db" "$directory/notary.p8" >>"$GITHUB_ENV"
    rm "$directory/identity.p12"
}

# Delete only the keychain and files created by this job.
cleanup() {
    local directory="$1"
    if [[ -f "$directory/signing.keychain-db" ]]; then security delete-keychain "$directory/signing.keychain-db"; fi
    if [[ -d "$directory" ]]; then rm -rf "$directory"; fi
}

# Require runner-owned paths so the local login Keychain is never modified.
main() {
    if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then usage; return; fi
    [[ $# == 1 && -n "${RUNNER_TEMP:-}" && "${GITHUB_ACTIONS:-}" == true ]] || { usage >&2; return 2; }
    case "$1" in
        setup) setup "$RUNNER_TEMP/aws-auto-approve-signing" ;;
        cleanup) cleanup "$RUNNER_TEMP/aws-auto-approve-signing" ;;
        *) usage >&2; return 2 ;;
    esac
}

main "$@"
