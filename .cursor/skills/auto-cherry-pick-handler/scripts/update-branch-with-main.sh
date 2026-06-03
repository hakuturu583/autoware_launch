#!/usr/bin/env bash
# Rebase cherry-pick branch onto latest origin/tier4/main inside worktree.
#
# Usage:
#   update-branch-with-main.sh --pr <downstream_pr> --upstream-pr <M>

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
    echo "usage: update-branch-with-main.sh --pr <downstream_pr> --upstream-pr <M>" >&2
    exit 1
}

cache="$(pr_cache_dir "$upstream_pr")"
ensure_pr_cache_dir "$upstream_pr"
wt="$(worktree_path "$downstream_pr")"
branch="$(cherry_pick_branch "$upstream_pr")"
conflict_file="${cache}/conflicts.txt"
: >"$conflict_file"

if [[ ! -d $wt ]]; then
    echo "error: worktree missing at ${wt}; run setup-worktree.sh first" >&2
    exit 2
fi

cd "$wt"
git fetch origin "${TARGET_BRANCH}" >&2

if git rebase "origin/${TARGET_BRANCH}"; then
    echo "update-branch-with-main: SUCCESS (rebased onto origin/${TARGET_BRANCH})"
    echo "  HEAD: $(git rev-parse --short HEAD)"
    exit 0
fi

git diff --name-only --diff-filter=U | tee -a "$conflict_file"
failed_ref="$(git rev-parse --short REBASE_HEAD 2>/dev/null || git rev-parse --short HEAD)"

jq -n \
    --argjson upstream_pr "$upstream_pr" \
    --argjson downstream_pr "$downstream_pr" \
    --arg failed_ref "$failed_ref" \
    --arg branch "$branch" \
    --arg work_dir "$wt" \
    --argjson conflict_files "$(jq -R -s 'split("\n") | map(select(length>0))' "$conflict_file")" \
    '{
    upstream_pr: $upstream_pr,
    downstream_pr: $downstream_pr,
    operation: "rebase",
    failed_ref: $failed_ref,
    branch: $branch,
    work_dir: $work_dir,
    conflict_files: $conflict_files,
    agent_action: "resolve conflicts, git add, git rebase --continue"
  }' >"${cache}/conflict-state.json"

write_conflict_checklist "$cache" "$upstream_pr" "$downstream_pr" "$failed_ref" "$wt" "$branch" "rebase onto origin/${TARGET_BRANCH}"

echo "update-branch-with-main: CONFLICTS — resolve in ${wt}" >&2
echo "  guide: ${cache}/conflict-resolution-checklist.md" >&2
exit 1
