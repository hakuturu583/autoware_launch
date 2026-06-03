#!/usr/bin/env bash
# Orchestrate automated steps for one downstream cherry-pick PR.
#
# Usage:
#   run-pr.sh <downstream_pr> [--skip-sync] [--skip-cherry-pick] [--skip-rebase]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_gh
require_jq

downstream_pr="${1:?usage: run-pr.sh <downstream_pr> [--skip-sync] [--skip-cherry-pick] [--skip-rebase]}"
shift || true

skip_sync=false
skip_cherry_pick=false
skip_rebase=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    --skip-sync)
        skip_sync=true
        shift
        ;;
    --skip-cherry-pick)
        skip_cherry_pick=true
        shift
        ;;
    --skip-rebase)
        skip_rebase=true
        shift
        ;;
    *)
        echo "error: unknown argument $1" >&2
        exit 1
        ;;
    esac
done

eval "$("${SCRIPT_DIR}/parse-pr.sh" "$downstream_pr" --export)"

echo "run-pr: ${DOWNSTREAM_FULL}#${DOWNSTREAM_PR} → ${UPSTREAM_REF}#${UPSTREAM_PR}"

if ! $skip_sync; then
    "${SCRIPT_DIR}/sync-tier4-main.sh"
fi

load_worktree_exports "$DOWNSTREAM_PR" "$UPSTREAM_PR" "$SCRIPT_DIR"

if ! $skip_cherry_pick; then
    wt_commits="$(git -C "${CHERRY_PICK_WORKTREE}" rev-list --count "origin/${TARGET_BRANCH}..HEAD" 2>/dev/null || echo 0)"
    if [[ $wt_commits -eq 0 ]]; then
        echo "run-pr: attempting naive cherry-pick..."
        set +e
        "${SCRIPT_DIR}/try-cherry-pick.sh" --pr "$DOWNSTREAM_PR" --upstream-pr "$UPSTREAM_PR"
        cp_status=$?
        set -e
        if [[ $cp_status -eq 2 ]]; then
            exit 2
        fi
    else
        echo "run-pr: branch already has ${wt_commits} commit(s); skipping try-cherry-pick"
    fi
fi

if ! $skip_rebase; then
    set +e
    "${SCRIPT_DIR}/update-branch-with-main.sh" --pr "$DOWNSTREAM_PR" --upstream-pr "$UPSTREAM_PR"
    rebase_status=$?
    set -e
    if [[ $rebase_status -eq 2 ]]; then
        exit 2
    fi
fi

"${SCRIPT_DIR}/gather-context.sh" "$UPSTREAM_PR" --pr "$DOWNSTREAM_PR"

cache="$(pr_cache_dir "$UPSTREAM_PR")"
echo ""
echo "=== run-pr: automated steps complete ==="
echo "  Downstream: ${DOWNSTREAM_FULL}#${DOWNSTREAM_PR}"
echo "  Upstream:   ${UPSTREAM_REF}#${UPSTREAM_PR}"
echo "  Worktree:   ${CHERRY_PICK_WORKTREE}"
echo "  Branch:     ${CHERRY_PICK_BRANCH}"
echo "  Cache:      ${cache}/context-bundle.md"
echo ""
echo "Agent next (required):"
echo "  1. Read and fill ${cache}/agent-assessment.md"
echo "  2. Resolve conflicts in ${CHERRY_PICK_WORKTREE} if any"
echo "  3. Fill ${cache}/pr-comment-report.md"
echo "  4. ${SCRIPT_DIR}/commit-cherry-pick-fix.sh --pr ${DOWNSTREAM_PR} --upstream-pr ${UPSTREAM_PR}"
echo "  5. ${SCRIPT_DIR}/push-cherry-pick-branch.sh --pr ${DOWNSTREAM_PR} --upstream-pr ${UPSTREAM_PR}"
echo "  6. ${SCRIPT_DIR}/post-pr-comment.sh --pr ${DOWNSTREAM_PR} --upstream-pr ${UPSTREAM_PR}"
echo "  7. ${SCRIPT_DIR}/remove-worktree.sh --pr ${DOWNSTREAM_PR} --upstream-pr ${UPSTREAM_PR}"
