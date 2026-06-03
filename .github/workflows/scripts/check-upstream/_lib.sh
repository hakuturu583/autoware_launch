#!/usr/bin/env bash
# Shared helpers for check-upstream cherry-pick workflow scripts.

set -euo pipefail

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_lib_dir}/config.env"

SCRIPT_ROOT="${_lib_dir}"
CACHE_ROOT="${SCRIPT_ROOT}/.cache"

cherry_pick_branch() {
    echo "${BRANCH_PREFIX}-$1"
}

repo_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        echo "error: not inside a git repository" >&2
        exit 1
    fi
}

require_gh() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "error: gh CLI is required" >&2
        exit 1
    fi
    if ! gh auth status >/dev/null 2>&1; then
        echo "error: gh is not authenticated (run: gh auth login)" >&2
        exit 1
    fi
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "error: jq is required" >&2
        exit 1
    fi
}

pr_cache_dir() {
    echo "${CACHE_ROOT}/pr-$1"
}

ensure_pr_cache_dir() {
    mkdir -p "$(pr_cache_dir "$1")"
}
