#!/usr/bin/env bash
# Stage resolved files and create a fix commit on top of the cherry-pick branch.
# Never amends or resets commits that may already exist on origin.
#
# Usage:
#   commit-cherry-pick-fix.sh --pr <downstream_pr> --upstream-pr <upstream_pr> [--message <msg>]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

downstream_pr=""
upstream_pr=""
message=""

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
    --message)
        message="$2"
        shift 2
        ;;
    *)
        echo "error: unknown argument $1" >&2
        exit 1
        ;;
    esac
done

[[ -n $downstream_pr && -n $upstream_pr ]] || {
    echo "usage: commit-cherry-pick-fix.sh --pr <downstream_pr> --upstream-pr <upstream_pr> [--message <msg>]" >&2
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

if git diff --quiet && git diff --cached --quiet; then
    echo "commit-cherry-pick-fix: nothing to commit (working tree clean)" >&2
    exit 0
fi

if [[ -z $message ]]; then
    message="fix: resolve cherry-pick conflicts (x2#${upstream_pr})"
fi

git add -A

if git diff --cached --quiet; then
    echo "commit-cherry-pick-fix: nothing staged after git add" >&2
    exit 0
fi

git commit -m "${message}"
echo "commit-cherry-pick-fix: created $(git rev-parse --short HEAD) on ${branch}"
echo "  Next: ${SCRIPT_DIR}/push-cherry-pick-branch.sh --pr ${downstream_pr} --upstream-pr ${upstream_pr}"
