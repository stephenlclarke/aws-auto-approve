#!/usr/bin/env bash
# USAGE: change-scope.sh [--help]
set -euo pipefail

# Commit fixture changes without user hooks, signing or global Git settings.
commit_fixture() {
    git add -A
    git -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -qm fixture
}

# Check the action's real filter against an isolated repository history.
assert_scope() {
    local expected=$1 event=$2 base=$3 head=$4 actual
    actual=$(env -u BASH_ENV -u ENV CI_EVENT_NAME="$event" CI_BASE_SHA="$base" CI_HEAD_SHA="$head" bash "$SCRIPT")
    if [[ "$actual" != "required=$expected" ]]; then
        printf 'Expected %s, received %s (%s).\n' "$expected" "$actual" "$event" >&2
        exit 1
    fi
    ((CHECKS += 1))
}

# Exercise documentation-only, mixed, renamed and invalid comparisons.
main() {
    if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
        printf 'Usage: %s [--help]\nTest CI path filtering in a temporary Git repository.\n' "$(basename "$0")"
        return
    fi
    if [[ $# -ne 0 ]]; then return 2; fi

    SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/.github/actions/change-scope/check.sh"
    FIXTURE=$(mktemp -d)
    trap 'rm -rf "$FIXTURE"' EXIT
    cd "$FIXTURE"
    git init -q
    git config user.name 'CI Fixture'
    git config user.email 'ci@example.invalid'
    mkdir -p docs nested/docs .github/workflows
    printf 'source\n' > source.swift
    printf 'readme\n' > README.md
    commit_fixture
    BASE=$(git rev-parse HEAD)
    CHECKS=0

    printf 'updated\n' >> README.md
    printf 'guide\n' > 'docs/guide with spaces.md'
    printf 'nested\n' > nested/docs/guide.md
    commit_fixture
    DOCS=$(git rev-parse HEAD)
    assert_scope false pull_request "$BASE" "$DOCS"
    assert_scope false push "$BASE" "$DOCS"
    assert_scope false push "$DOCS" "$DOCS"
    assert_scope true workflow_dispatch "$BASE" "$DOCS"
    assert_scope true schedule "$BASE" "$DOCS"
    assert_scope true push 0000000000000000000000000000000000000000 "$DOCS"

    printf 'changed\n' >> source.swift
    commit_fixture
    MIXED=$(git rev-parse HEAD)
    assert_scope true pull_request "$BASE" "$MIXED"
    git mv source.swift docs/source.swift
    commit_fixture
    assert_scope true push "$MIXED" HEAD
    RENAMED=$(git rev-parse HEAD)
    git rm -q 'docs/guide with spaces.md'
    commit_fixture
    assert_scope false push "$RENAMED" HEAD
    DELETED=$(git rev-parse HEAD)
    printf 'workflow\n' > .github/workflows/test.yml
    commit_fixture
    assert_scope true push "$DELETED" HEAD

    if env -u BASH_ENV -u ENV CI_EVENT_NAME=push CI_BASE_SHA=invalid CI_HEAD_SHA=HEAD bash "$SCRIPT" > invalid-output 2>/dev/null; then
        printf 'Invalid Git comparisons must fail.\n' >&2
        exit 1
    fi
    test ! -s invalid-output
    ((CHECKS += 1))

    git checkout -qb base-only "$DOCS"
    printf 'base change\n' >> source.swift
    commit_fixture
    assert_scope false pull_request HEAD "$DOCS"
    printf 'CI path filtering: %s checks passed.\n' "$CHECKS"
}

main "$@"
