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
    bash "$ROOT/Integration/aws-auto-approve-login" "$@" >/dev/null 2>&1 || result=$?
    [[ "$result" == "$expected" ]] || { printf 'Expected %s; got %s\n' "$expected" "$result" >&2; exit 1; }
}
check 0 --help
check 2
check 0 --if-needed fixture
[[ "$(cat "$TEST_ROOT/calls")" == sts ]]
check 0 fixture
export TEST_LOGIN_RESULT=7
check 1 fixture
unset TEST_LOGIN_RESULT
export TEST_HELPER_RESULT=8
check 1 fixture
unset TEST_HELPER_RESULT
export TEST_STS_RESULT=9
check 9 fixture
unset TEST_STS_RESULT
export TEST_HOLD_LOGIN=1 TEST_HELPER_FAST_FAIL=1
SECONDS=0
check 1 fixture
[[ $SECONDS -lt 5 ]]
printf 'AWS CLI integration: 8 checks passed.\n'
