#!/usr/bin/env bash
# USAGE: check-commit.sh SUBJECT - validate a Conventional Commit or squash-PR title.
set -euo pipefail
if [[ $# != 1 || ! "$1" =~ ^(feat|fix|perf|refactor|build|ci|docs|style|test|chore|revert)(\([^\)]+\))?\!?:\ .+ ]]; then
    printf 'Use a Conventional Commit, for example: feat: add configuration script\n' >&2
    exit 1
fi
