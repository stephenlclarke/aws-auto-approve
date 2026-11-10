#!/usr/bin/env bash
# USAGE: login.sh - exercise CLI status and pipeline handling without network access.
set -euo pipefail
unset BASH_ENV ENV
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
export AWS_AUTO_TEST_DIR="$TEST_ROOT"
mkdir "$TEST_ROOT/bin"
cat > "$TEST_ROOT/bin/aws" <<'STUB'
#!/bin/bash
if [[ "$1" == sts ]]; then
    printf 'sts\n' >> "$AWS_AUTO_TEST_DIR/calls"
    exit "${TEST_STS_RESULT:-0}"
fi
printf 'login\n' >> "$AWS_AUTO_TEST_DIR/calls"
printf 'fixture authentication message\n'
if [[ ${TEST_HOLD_LOGIN:-0} == 1 ]]; then exec sleep 10; fi
exit "${TEST_LOGIN_RESULT:-0}"
STUB
cat > "$TEST_ROOT/bin/aws-auto-approve" <<'STUB'
#!/bin/bash
if [[ ${TEST_HELPER_FAST_FAIL:-0} == 1 ]]; then exit 8; fi
cat >/dev/null
exit "${TEST_HELPER_RESULT:-0}"
STUB
chmod +x "$TEST_ROOT/bin/"*
export PATH="$TEST_ROOT/bin:/usr/bin:/bin"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Check each pipeline exit independently, including a helper that fails.
check() {
    local expected="$1" result=0
    shift
    bash "$ROOT/Integration/aws-auto-approve-login" "$@" >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr" || result=$?
    [[ "$result" == "$expected" ]] || { printf 'Expected %s; got %s\n' "$expected" "$result" >&2; exit 1; }
}
# Verify status is emitted only for profiles whose role access succeeds.
check_status() {
    [[ "$(cat "$TEST_ROOT/stderr")" == '[v] [fixture] AWS session is ready' ]]
    [[ ! -s "$TEST_ROOT/stdout" ]]
}

# Failed sign-in or role access must never claim that the session is ready.
check_no_status() {
    if grep -Fq 'AWS session is ready' "$TEST_ROOT/stderr"; then
        printf 'Unexpected success status after failed access.\n' >&2
        exit 1
    fi
}
check 0 --help
check 2
check 0 --if-needed fixture
check_status
[[ "$(cat "$TEST_ROOT/calls")" == sts ]]
check 0 fixture
check_status
export TEST_LOGIN_RESULT=7
check 1 fixture
check_no_status
unset TEST_LOGIN_RESULT
export TEST_HELPER_RESULT=8
check 1 fixture
check_no_status
unset TEST_HELPER_RESULT
export TEST_STS_RESULT=9
check 9 fixture
check_no_status
unset TEST_STS_RESULT
export TEST_HOLD_LOGIN=1 TEST_HELPER_FAST_FAIL=1
SECONDS=0
check 1 fixture
check_no_status
[[ $SECONDS -lt 5 ]]
unset TEST_HOLD_LOGIN TEST_HELPER_FAST_FAIL
export TEST_STS_RESULT=9
check 9 --if-needed fixture
check_no_status
unset TEST_STS_RESULT
unset SCRIPT_COLOUR NO_COLOR
export TERM=xterm-256color
# A real terminal gets green text; either colour override removes escape codes.
script -q "$TEST_ROOT/terminal" bash "$ROOT/Integration/aws-auto-approve-login" --if-needed fixture >/dev/null
[[ "$(cat "$TEST_ROOT/terminal")" == *$'\033[32m[v] [fixture] AWS session is ready\033[0m'* ]]
SCRIPT_COLOUR=off script -q "$TEST_ROOT/terminal" bash "$ROOT/Integration/aws-auto-approve-login" --if-needed fixture >/dev/null
[[ "$(cat "$TEST_ROOT/terminal")" != *$'\033['* ]]
NO_COLOR=1 script -q "$TEST_ROOT/terminal" bash "$ROOT/Integration/aws-auto-approve-login" --if-needed fixture >/dev/null
[[ "$(cat "$TEST_ROOT/terminal")" != *$'\033['* ]]
printf 'AWS CLI integration: 12 checks passed.\n'
