#!/usr/bin/env bash
# USAGE: check-commit.sh SUBJECT - validate a Conventional Commit or squash-PR title.
set -euo pipefail
if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
    printf 'Usage: %s SUBJECT\nValidate a Conventional Commit or squash-PR title.\n' "$(basename "${BASH_SOURCE[0]:-$0}")"
    exit 0
fi
if [[ $# != 1 ]]; then printf 'Supply exactly one commit subject.\n' >&2; exit 2; fi
if [[ ! "$1" =~ ^(feat|fix|perf|refactor|build|ci|docs|style|test|chore|revert)(\([^\)]+\))?\!?:\ .+ ]]; then
    printf 'Use a Conventional Commit, for example: feat: add configuration script\n' >&2
    exit 1
fi
