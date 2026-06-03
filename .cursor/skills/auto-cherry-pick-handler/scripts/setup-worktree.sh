#!/usr/bin/env bash
# Create an isolated git worktree for one downstream cherry-pick PR.
#
# Usage:
#   setup-worktree.sh --pr <downstream_pr> --upstream-pr <upstream_pr>
#
# Creates:
#   worktrees/pr-<downstream_pr>/ on branch cherry-pick/x2-<upstream_pr>
# Checks out origin/<branch> when the PR branch already exists on remote.

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
    echo "usage: setup-worktree.sh --pr <downstream_pr> --upstream-pr <upstream_pr>" >&2
    exit 1
}

root="$(repo_root)"
branch="$(cherry_pick_branch "$upstream_pr")"
wt="$(worktree_path "$downstream_pr")"

mkdir -p "$WORKTREE_ROOT"
cd "$root"

# Previous remove-worktree or manual deletes can leave a prunable registration that blocks
# `git worktree add` with: branch is already checked out at <missing path>.
prune_stale_worktrees "$root"

git fetch origin "${TARGET_BRANCH}" >&2
git fetch origin "${branch}" >&2 || true

if [[ -d $wt ]]; then
    if git -C "$wt" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "setup-worktree: reusing existing worktree ${wt}" >&2
    else
        echo "setup-worktree: ${wt} exists but is not a git worktree; removing" >&2
        rm -rf "$wt"
        prune_stale_worktrees "$root"
    fi
fi

if [[ ! -d $wt ]]; then
    start_ref="origin/${TARGET_BRANCH}"
    if git rev-parse "origin/${branch}" >/dev/null 2>&1; then
        start_ref="origin/${branch}"
        echo "setup-worktree: using existing remote branch ${branch}" >&2
    else
        echo "setup-worktree: new branch ${branch} from ${TARGET_BRANCH}" >&2
    fi
    echo "setup-worktree: creating ${wt}" >&2
    if ! git worktree add -B "${branch}" "$wt" "${start_ref}"; then
        echo "setup-worktree: worktree add failed; pruning stale registrations and retrying once" >&2
        prune_stale_worktrees "$root"
        git worktree add -B "${branch}" "$wt" "${start_ref}"
    fi
fi

"${SCRIPT_DIR}/ensure-x2-remote.sh" --fetch-commits "$upstream_pr" >/dev/null

echo "export CHERRY_PICK_WORKTREE=${wt}"
echo "export CHERRY_PICK_BRANCH=${branch}"
echo "export DOWNSTREAM_PR=${downstream_pr}"
echo "export UPSTREAM_PR=${upstream_pr}"
echo "setup-worktree: ready at ${wt} (branch ${branch})" >&2
