#!/usr/bin/env bash
# Ensure git remote 'x2' points at autoware_launch.x2; optionally fetch PR commits.
#
# Usage:
#   ensure-x2-remote.sh
#   ensure-x2-remote.sh --fetch-commits <upstream_pr_number>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_gh
require_jq

root="$(repo_root)"
cd "$root"

if git remote get-url "${UPSTREAM_REMOTE}" >/dev/null 2>&1; then
    echo "remote ${UPSTREAM_REMOTE} exists: $(git remote get-url "${UPSTREAM_REMOTE}")"
else
    git remote add "${UPSTREAM_REMOTE}" "${UPSTREAM_REMOTE_URL}"
    echo "remote ${UPSTREAM_REMOTE} added"
fi

git fetch "${UPSTREAM_REMOTE}" "${TARGET_BRANCH}" >&2
echo "fetched ${UPSTREAM_REMOTE}/${TARGET_BRANCH}" >&2

if [[ ${1:-} == "--fetch-commits" ]]; then
    pr="${2:?usage: ensure-x2-remote.sh --fetch-commits <pr_number>}"
    cache="$(pr_cache_dir "$pr")"
    commits_file="${cache}/commits.json"

    if [[ ! -f $commits_file ]]; then
        "${SCRIPT_DIR}/fetch-upstream-pr.sh" "$pr"
    fi

    while IFS= read -r sha; do
        [[ -z $sha ]] && continue
        echo "fetching commit ${sha}" >&2
        git fetch "${UPSTREAM_REMOTE}" "${sha}" >&2
    done < <(jq -r '.[].sha' "$commits_file")
fi

echo "ensure-x2-remote: done"
