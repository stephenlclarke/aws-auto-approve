#!/usr/bin/env bash
# USAGE: release-ready.sh SHA - report whether the current main commit passed release gates.
set -euo pipefail
SHA="${1:-}"
[[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || exit 2
: "${GITHUB_REPOSITORY:?}"
MAIN_SHA="$(gh api "repos/$GITHUB_REPOSITORY/commits/main" --jq .sha)"
if [[ "$MAIN_SHA" != "$SHA" ]]; then printf 'ready=false\n'; exit 0; fi
CHECK_FILE="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/aws-release-checks.XXXXXX")"
trap 'rm -f "$CHECK_FILE"' EXIT
gh api "repos/$GITHUB_REPOSITORY/commits/$SHA/check-runs?filter=latest&per_page=100" >"$CHECK_FILE"
jq -r '
    ["quality","unit-tests","ASAN","TSAN","CodeQL (Swift)","CodeQL (JavaScript)","CodeQL (Ruby)","CodeQL (Actions)","release-tools"] as $required |
    if .total_count > 100 then error("Too many checks; refusing an incomplete gate decision") else
      ([.check_runs[] | select(.app.slug=="github-actions")] | group_by(.name) | map(max_by(.id))) as $checks |
      "ready=\(all($required[]; . as $name | any($checks[]; .name==$name and .status=="completed" and .conclusion=="success")))"
    end
' "$CHECK_FILE"
