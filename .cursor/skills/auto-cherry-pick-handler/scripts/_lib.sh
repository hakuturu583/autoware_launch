#!/usr/bin/env bash
# Shared helpers for auto-cherry-pick-handler scripts.

set -euo pipefail

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "${_lib_dir}/config.env"

SKILL_ROOT="$(cd "${_lib_dir}/.." && pwd)"
CACHE_ROOT="${SKILL_ROOT}/.cache"
WORKTREE_ROOT="${SKILL_ROOT}/${WORKTREES_DIR}"

cherry_pick_branch() {
    echo "${BRANCH_PREFIX}-$1"
}

worktree_path() {
    echo "${WORKTREE_ROOT}/pr-$1"
}

# Drop worktree registrations whose directories were removed (e.g. incomplete cleanup).
prune_stale_worktrees() {
    local root="$1"
    git -C "$root" worktree prune >&2 || true
}

# Run setup-worktree.sh and eval exports. Never silence stderr — setup failures must be visible.
load_worktree_exports() {
    local downstream_pr="$1"
    local upstream_pr="$2"
    local script_dir="${3:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
    local setup_out=""
    local exports=""

    if ! setup_out="$("${script_dir}/setup-worktree.sh" --pr "$downstream_pr" --upstream-pr "$upstream_pr")"; then
        echo "error: setup-worktree.sh failed for downstream #${downstream_pr}" >&2
        return 1
    fi

    exports="$(grep '^export ' <<<"$setup_out" || true)"
    if [[ -z $exports ]]; then
        echo "error: setup-worktree.sh produced no export lines" >&2
        return 1
    fi
    # shellcheck disable=SC2086
    eval "$exports"

    if [[ -z ${CHERRY_PICK_WORKTREE:-} || ! -d $CHERRY_PICK_WORKTREE ]]; then
        echo "error: CHERRY_PICK_WORKTREE is missing or not a directory: ${CHERRY_PICK_WORKTREE:-}" >&2
        return 1
    fi
}

ensure_worktree() {
    load_worktree_exports "$1" "$2" "${3:-}"
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

is_cherry_pick_pr_text() {
    local text="$1"
    [[ $text =~ [Cc]herry[-\ ]?pick ]] || [[ $text == *"🍒"* ]]
}

write_conflict_checklist() {
    local cache="$1"
    local upstream_pr="$2"
    local downstream_pr="$3"
    local failed_ref="$4"
    local work_dir="$5"
    local branch="$6"
    local operation="$7"
    local conflict_file="${cache}/conflicts.txt"

    cat >"${cache}/conflict-resolution-checklist.md" <<EOF
# Conflict resolution — ${UPSTREAM_FULL}#${upstream_pr}

**Operation:** ${operation}
**Stopped at:** \`${failed_ref}\`

**Work directory (required):** \`${work_dir}\`
**Branch:** \`${branch}\`

## Conflicted files

$(sed 's/^/- /' "$conflict_file" 2>/dev/null || echo "- (see git status)")

## Agent steps (required)

1. \`cd ${work_dir}\` — all git commands for this PR happen here only.
2. Read \`agent-assessment.md\` and [docs/xx1-x2-launch-knowledge-reference.md](../docs/xx1-x2-launch-knowledge-reference.md) §8.
3. Read upstream: \`pr-body.md\`, \`linked-prs/*/body.md\`, \`diff.patch\`.
4. Resolve each conflict; \`git add\`; continue the operation (\`git rebase --continue\` or \`git cherry-pick --continue\`) if a rebase/cherry-pick is in progress.
5. \`commit-cherry-pick-fix.sh --pr ${downstream_pr} --upstream-pr ${upstream_pr}\` — **new commit only** (never \`git reset --soft\`, \`git commit --amend\` on published commits, or rewrite pushed history).
6. \`push-cherry-pick-branch.sh --pr ${downstream_pr} --upstream-pr ${upstream_pr}\` — if remote diverged, script adds a **merge commit** then pushes (never \`git push --force\` or \`git pull --rebase\`).
7. Fill \`pr-comment-report.md\` and run \`post-pr-comment.sh\`.

## Status

Conflicts **left in worktree** for agent resolution.
EOF
}
