#!/usr/bin/env bash
# USAGE: check.sh [--help]
# CI_EVENT_NAME selects push, pull_request or an unconditional full run.
# CI_BASE_SHA and CI_HEAD_SHA identify the comparison commits.
set -euo pipefail

# Classify changed paths without losing deletions, renames or unusual filenames.
main() {
    if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
        printf 'Usage: %s [--help]\nSet CI_EVENT_NAME, CI_BASE_SHA and CI_HEAD_SHA; prints required=true or false.\n' "$(basename "$0")"
        return
    fi
    if [[ $# -ne 0 ]]; then return 2; fi

    case "${CI_EVENT_NAME:-}" in
        pull_request) COMPARISON=("${CI_BASE_SHA:?}...${CI_HEAD_SHA:?}") ;;
        push)
            if [[ -z "${CI_BASE_SHA:-}" || "$CI_BASE_SHA" =~ ^0+$ ]]; then
                printf 'required=true\n'
                return
            fi
            COMPARISON=("$CI_BASE_SHA" "${CI_HEAD_SHA:?}")
            ;;
        *) printf 'required=true\n'; return ;;
    esac

    CHANGED_PATHS=$(mktemp)
    trap 'rm -f "$CHANGED_PATHS"' EXIT
    git diff --no-renames --name-only -z "${COMPARISON[@]}" -- > "$CHANGED_PATHS"
    REQUIRED=false
    while IFS= read -r -d '' path; do
        case "$path" in
            README.md|docs/*|*/docs/*) ;;
            *) REQUIRED=true; break ;;
        esac
    done < "$CHANGED_PATHS"
    printf 'required=%s\n' "$REQUIRED"
}

main "$@"
