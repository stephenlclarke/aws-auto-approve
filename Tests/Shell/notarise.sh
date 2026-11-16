#!/usr/bin/env bash
# USAGE: notarise.sh - verify release signing boundaries with synthetic responses.
set -euo pipefail
unset BASH_ENV ENV
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/bin" "$FIXTURE/App.app/Contents/MacOS"
cat >"$FIXTURE/bin/codesign" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == --display ]]; then
    case "$SCENARIO" in
        ad-hoc) printf 'Signature=adhoc\n' >&2 ;;
        *)
            printf 'Authority=Developer ID Application: Fixture\n' >&2
            if [[ "$SCENARIO" == wrong-team ]]; then printf 'TeamIdentifier=WRONGTEAM1\n' >&2; else printf 'TeamIdentifier=TESTTEAM01\n' >&2; fi
            if [[ "$SCENARIO" != no-runtime ]]; then printf 'flags=0x10000(runtime)\n' >&2; fi
            if [[ "$SCENARIO" != no-timestamp ]]; then printf 'Timestamp=fixture\n' >&2; fi
            ;;
    esac
elif [[ "$SCENARIO" == invalid-signature ]]; then exit 1
fi
SH
cat >"$FIXTURE/bin/ditto" <<'SH'
#!/usr/bin/env bash
touch "${@: -1}"
SH
cat >"$FIXTURE/bin/xcrun" <<'SH'
#!/usr/bin/env bash
printf '%s %s\n' "$1" "$2" >>"$CALLS"
case "$1 $2" in
    'notarytool submit')
        if [[ "$SCENARIO" == submit-failed ]]; then exit 7; fi
        if [[ "$SCENARIO" == rejected ]]; then status=Invalid; else status=Accepted; fi
        printf '{"status":"%s","id":"11111111-1111-1111-1111-111111111111"}\n' "$status"
        ;;
    'notarytool log')
        if [[ "$SCENARIO" == log-error ]]; then issues='[{"severity":"error"}]'; else issues='[]'; fi
        printf '{"status":"Accepted","issues":%s}\n' "$issues" >"${@: -1}"
        ;;
    'stapler staple') [[ "$SCENARIO" != staple-failed ]] ;;
    'stapler validate') [[ "$SCENARIO" != validation-failed ]] ;;
    *) exit 8 ;;
esac
SH
cat >"$FIXTURE/bin/spctl" <<'SH'
#!/usr/bin/env bash
printf 'Gatekeeper\n' >>"$CALLS"
[[ "$SCENARIO" != gatekeeper-failed ]]
SH
chmod +x "$FIXTURE/bin/"*
export PATH="$FIXTURE/bin:$PATH"
export CALLS="$FIXTURE/calls"
export CODESIGN_IDENTITY=fixture-identity APPLE_TEAM_ID=TESTTEAM01 NOTARY_KEYCHAIN_PROFILE=fixture-profile
checks=0

# Reject every unsuccessful trust stage; success must reach final assessment.
check() {
    local scenario="$1" expected="$2" status=0
    : >"$CALLS"
    SCENARIO="$scenario" bash "$ROOT/Tools/notarise.sh" "$FIXTURE/App.app" >"$FIXTURE/output" 2>&1 || status=$?
    if [[ "$expected" == success ]]; then
        [[ "$status" == 0 ]]
        printf 'notarytool submit\nnotarytool log\nstapler staple\nstapler validate\nGatekeeper\n' >"$FIXTURE/expected"
        cmp "$FIXTURE/expected" "$CALLS"
    else
        [[ "$status" != 0 ]]
        case "$scenario" in
            ad-hoc|wrong-team|no-runtime|no-timestamp|invalid-signature) [[ ! -s "$CALLS" ]] ;;
            rejected|submit-failed|log-error) ! grep -q '^stapler ' "$CALLS" ;;
        esac
    fi
    checks=$((checks + 1))
}

check accepted success
for scenario in ad-hoc wrong-team no-runtime no-timestamp invalid-signature rejected submit-failed log-error staple-failed validation-failed gatekeeper-failed; do
    check "$scenario" failure
done
if CODESIGN_IDENTITY=- bash "$ROOT/Tools/notarise.sh" --check >"$FIXTURE/output" 2>&1; then exit 1; fi
checks=$((checks + 1))
if env -u NOTARY_KEYCHAIN_PROFILE -u APPLE_NOTARY_KEY_PATH bash "$ROOT/Tools/notarise.sh" --check >"$FIXTURE/output" 2>&1; then exit 1; fi
checks=$((checks + 1))
printf 'Notarisation boundaries: %s checks passed.\n' "$checks"
