#!/usr/bin/env bash
# Cherry-pick upstream PR commits in an isolated git worktree.
#
# Usage:
#   try-cherry-pick.sh --pr <downstream_pr> --upstream-pr <M> [--abort-on-conflict]
#
# Exit codes:
#   0 — cherry-pick completed
#   1 — conflicts left for agent (default)
#   2 — fatal error

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_jq

downstream_pr=""
upstream_pr=""
leave_conflicts=true

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
    --abort-on-conflict)
        leave_conflicts=false
        shift
        ;;
    *)
        echo "error: unknown argument $1" >&2
        exit 1
        ;;
    esac
done

[[ -n $downstream_pr && -n $upstream_pr ]] || {
    echo "usage: try-cherry-pick.sh --pr <downstream_pr> --upstream-pr <M> [--abort-on-conflict]" >&2
    exit 2
}

cache="$(pr_cache_dir "$upstream_pr")"
branch="$(cherry_pick_branch "$upstream_pr")"
wt="$(worktree_path "$downstream_pr")"

if [[ ! -d $wt ]]; then
    load_worktree_exports "$downstream_pr" "$upstream_pr" "$SCRIPT_DIR"
fi

cd "$wt"

commits_file="${cache}/commits.json"
if [[ ! -f $commits_file ]]; then
    "${SCRIPT_DIR}/fetch-upstream-pr.sh" "$upstream_pr"
fi

conflict_file="${cache}/conflicts.txt"
: >"$conflict_file"

mapfile -t shas < <(jq -r '.[].sha' "$commits_file")

failed_sha=""
for sha in "${shas[@]}"; do
    echo "cherry-picking ${sha} in ${wt}..."
    if git cherry-pick -x "$sha"; then
        continue
    fi
    failed_sha="$sha"
    git diff --name-only --diff-filter=U | tee -a "$conflict_file"
    break
done

if [[ -n $failed_sha ]]; then
    jq -n \
        --argjson upstream_pr "$upstream_pr" \
        --argjson downstream_pr "$downstream_pr" \
        --arg failed_sha "$failed_sha" \
        --arg branch "$branch" \
        --arg work_dir "$wt" \
        --argjson leave_conflicts "$leave_conflicts" \
        --argjson conflict_files "$(jq -R -s 'split("\n") | map(select(length>0))' "$conflict_file")" \
        '{
      upstream_pr: $upstream_pr,
      downstream_pr: $downstream_pr,
      operation: "cherry-pick",
      failed_sha: $failed_sha,
      branch: $branch,
      work_dir: $work_dir,
      leave_conflicts: $leave_conflicts,
      conflict_files: $conflict_files,
      agent_action: "resolve conflicts per SKILL.md Phase 4, then git add && git cherry-pick --continue"
    }' >"${cache}/conflict-state.json"

    write_conflict_checklist "$cache" "$upstream_pr" "$downstream_pr" "$failed_sha" "$wt" "$branch" "cherry-pick"

    if $leave_conflicts; then
        echo "try-cherry-pick: CONFLICTS — resolve in ${wt}" >&2
        echo "  export CHERRY_PICK_WORKTREE=${wt}" >&2
        echo "  guide: ${cache}/conflict-resolution-checklist.md" >&2
        exit 1
    fi

    git cherry-pick --abort || true
    echo "try-cherry-pick: aborted (--abort-on-conflict)" >&2
    exit 1
fi

echo "try-cherry-pick: SUCCESS"
echo "  export CHERRY_PICK_WORKTREE=${wt}"
echo "  export CHERRY_PICK_BRANCH=${branch}"
echo "  work_dir: ${wt}"
echo "  HEAD: $(git rev-parse --short HEAD)"
exit 0
