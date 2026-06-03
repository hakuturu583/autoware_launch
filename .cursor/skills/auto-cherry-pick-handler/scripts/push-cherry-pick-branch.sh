#!/usr/bin/env bash
# Publish the cherry-pick branch: push only, merge.
#
# Usage:
#   push-cherry-pick-branch.sh --pr <downstream_pr> --upstream-pr <upstream_pr>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

downstream_pr=""
upstream_pr=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --pr)
        downstream_pr="$2"
        shift 2
        ;;
    --upstream-pr)
        upstream_pr="$2"
        shift 2
        ;;
    *)
        echo "error: unknown argument $1" >&2
        exit 1
        ;;
    esac
done

[[ -n $downstream_pr && -n $upstream_pr ]] || {
    echo "usage: push-cherry-pick-branch.sh --pr <downstream_pr> --upstream-pr <upstream_pr>" >&2
    exit 1
}

wt="$(worktree_path "$downstream_pr")"
branch="$(cherry_pick_branch "$upstream_pr")"

if [[ ! -d $wt ]]; then
    echo "error: worktree missing at ${wt}; run setup-worktree.sh first" >&2
    exit 1
fi

cd "$wt"

if [[ "$(git branch --show-current)" != "$branch" ]]; then
    echo "error: worktree is on '$(git branch --show-current)', expected '${branch}'" >&2
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "error: uncommitted changes in ${wt}; run commit-cherry-pick-fix.sh first" >&2
    exit 1
fi

git fetch origin "${branch}" >&2 || true

remote_ref="origin/${branch}"
merge_msg="merge: integrate remote ${branch} before publishing cherry-pick fix (x2#${upstream_pr})"

push_once() {
    git push -u origin HEAD 2>&1
}

integrate_remote_with_merge() {
    if ! git rev-parse "${remote_ref}" >/dev/null 2>&1; then
        return 0
    fi

    if git merge-base --is-ancestor "${remote_ref}" HEAD; then
        echo "push-cherry-pick-branch: local branch already contains ${remote_ref}" >&2
        return 0
    fi

    echo "push-cherry-pick-branch: merging ${remote_ref} (merge commit, no rebase)" >&2
    git merge "${remote_ref}" --no-edit -m "${merge_msg}"
}

push_out=""
if push_out="$(push_once)"; then
    echo "push-cherry-pick-branch: pushed ${branch} ($(git rev-parse --short HEAD))"
    exit 0
fi

if ! grep -qiE 'rejected|non-fast-forward|fetch first|behind' <<<"$push_out"; then
    echo "error: git push failed:" >&2
    echo "$push_out" >&2
    exit 1
fi

echo "push-cherry-pick-branch: push rejected; integrating remote with merge commit" >&2
echo "$push_out" >&2

if ! integrate_remote_with_merge; then
    echo "error: git merge ${remote_ref} failed — resolve conflicts, commit, re-run this script" >&2
    exit 1
fi

if push_out="$(push_once)"; then
    echo "push-cherry-pick-branch: pushed ${branch} after merge ($(git rev-parse --short HEAD))"
    exit 0
fi

echo "error: push still rejected after merge commit:" >&2
echo "$push_out" >&2
exit 1
