#!/usr/bin/env bash
# Remove worktree after work is done (keeps remote branch on origin).
#
# Usage: remove-worktree.sh --pr <downstream_pr> [--upstream-pr <M>] [--delete-branch]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

downstream_pr=""
upstream_pr=""
delete_branch=false

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
    --delete-branch)
        delete_branch=true
        shift
        ;;
    *)
        echo "error: unknown argument $1" >&2
        exit 1
        ;;
    esac
done

[[ -n $downstream_pr ]] || {
    echo "usage: remove-worktree.sh --pr <downstream_pr> [--upstream-pr <M>] [--delete-branch]" >&2
    exit 1
}

root="$(repo_root)"
wt="$(worktree_path "$downstream_pr")"
branch=""
if [[ -n $upstream_pr ]]; then
    branch="$(cherry_pick_branch "$upstream_pr")"
fi

cd "$root"

if [[ -d $wt ]]; then
    git worktree remove "$wt" --force 2>/dev/null || git worktree remove -f "$wt"
    echo "remove-worktree: removed ${wt}"
else
    echo "remove-worktree: no directory at ${wt}; pruning stale git worktree registrations" >&2
fi

prune_stale_worktrees "$root"

if $delete_branch && [[ -n $branch ]]; then
    git branch -D "${branch}" 2>/dev/null || true
    echo "remove-worktree: deleted local branch ${branch}"
fi
