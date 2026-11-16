#!/usr/bin/env bash
# USAGE: ci-signing.sh - verify isolated runner Keychain registration and cleanup.
set -euo pipefail
unset BASH_ENV ENV
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/bin" "$FIXTURE/runner"
cat >"$FIXTURE/bin/security" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
command="$1"; shift
case "$command" in
    list-keychains)
        if [[ "${3:-}" == -s ]]; then
            shift 3
            printf '%s\n' "$@" >"$SEARCH_LIST"
        else
            while IFS= read -r path; do printf '    "%s"\n' "$path"; done <"$SEARCH_LIST"
        fi
        ;;
    create-keychain) touch "${@: -1}" ;;
    import) [[ "$SCENARIO" != import-failed ]] ;;
    find-identity) printf '1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Developer ID Application: Fixture"\n' ;;
    delete-keychain)
        cmp "$SEARCH_LIST" "$ORIGINAL_LIST"
        rm "$1"
        ;;
    set-keychain-settings|unlock-keychain|set-key-partition-list) ;;
    *) exit 9 ;;
esac
SH
cat >"$FIXTURE/bin/openssl" <<'SH'
#!/usr/bin/env bash
printf 'synthetic-keychain-password\n'
SH
chmod +x "$FIXTURE/bin/"*
export PATH="$FIXTURE/bin:$PATH"
export SEARCH_LIST="$FIXTURE/search-list" ORIGINAL_LIST="$FIXTURE/original-list"
export RUNNER_TEMP="$FIXTURE/runner" GITHUB_ENV="$FIXTURE/github-env" GITHUB_ACTIONS=true
export MACOS_CERTIFICATE_P12=Zml4dHVyZQ== MACOS_CERTIFICATE_PASSWORD=synthetic-password APPLE_NOTARY_KEY_P8=synthetic-api-key
export SCENARIO=accepted
printf '/Users/runner/Library/Keychains/login.keychain-db\n/Users/runner/Keychains/Existing Identity.keychain-db\n' >"$ORIGINAL_LIST"
cp "$ORIGINAL_LIST" "$SEARCH_LIST"

bash "$ROOT/Tools/ci-signing.sh" setup
{ printf '%s\n' "$RUNNER_TEMP/aws-auto-approve-signing/signing.keychain-db"; cat "$ORIGINAL_LIST"; } >"$FIXTURE/expected-list"
cmp "$SEARCH_LIST" "$FIXTURE/expected-list"
grep -Fxq 'CODESIGN_IDENTITY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "$GITHUB_ENV"
bash "$ROOT/Tools/ci-signing.sh" cleanup
cmp "$SEARCH_LIST" "$ORIGINAL_LIST"
[[ ! -d "$RUNNER_TEMP/aws-auto-approve-signing" ]]

if SCENARIO=import-failed bash "$ROOT/Tools/ci-signing.sh" setup; then exit 1; fi
bash "$ROOT/Tools/ci-signing.sh" cleanup
cmp "$SEARCH_LIST" "$ORIGINAL_LIST"
[[ ! -d "$RUNNER_TEMP/aws-auto-approve-signing" ]]

if env -u APPLE_NOTARY_KEY_P8 bash "$ROOT/Tools/ci-signing.sh" setup >"$FIXTURE/output" 2>&1; then exit 1; fi
[[ ! -d "$RUNNER_TEMP/aws-auto-approve-signing" ]]
if GITHUB_ACTIONS=false bash "$ROOT/Tools/ci-signing.sh" setup >"$FIXTURE/output" 2>&1; then exit 1; fi
printf 'Runner signing: registration, existing paths with spaces, restoration, partial import failure and credential guards passed.\n'
