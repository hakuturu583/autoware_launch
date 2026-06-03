#!/usr/bin/env bash
# Bootstrap a draft cherry-pick PR from one upstream x2 PR (CI or local).
#
# Usage:
#   create-cherry-pick-draft.sh --upstream-pr <N>
#
# In CI, the workflow copies this directory to ${RUNNER_TEMP}/check-upstream-scripts
# before invoking it, because cherry-pick branches are based on tier4/main and may
# not contain these scripts until the workflow is merged.
#
# Exit codes:
#   0 — draft PR created
#   1 — fatal error
#   2 — skipped (duplicate PR already exists)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"

require_jq
if [[ -z ${GH_TOKEN:-} ]]; then
    require_gh
fi

upstream_pr=""

while [[ $# -gt 0 ]]; do
    case "$1" in
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

[[ -n $upstream_pr ]] || {
    echo "usage: create-cherry-pick-draft.sh --upstream-pr <N>" >&2
    exit 1
}

branch="$(cherry_pick_branch "$upstream_pr")"
cache="$(pr_cache_dir "$upstream_pr")"
upstream_ref="${UPSTREAM_FULL}"
root="$(repo_root)"

# Skip if any downstream PR already exists for this upstream branch.
existing_prs="$(gh pr list \
    --repo "${DOWNSTREAM_FULL}" \
    --head "${branch}" \
    --state all \
    --json number \
    --limit 1)"
if [[ $(echo "$existing_prs" | jq 'length') -gt 0 ]]; then
    existing_num="$(echo "$existing_prs" | jq -r '.[0].number')"
    echo "create-cherry-pick-draft: skip x2#${upstream_pr} — PR #${existing_num} already exists" >&2
    jq -n \
        --argjson upstream_pr "$upstream_pr" \
        --argjson downstream_pr "$existing_num" \
        --arg branch "$branch" \
        --arg status "skipped" \
        '{upstream_pr: $upstream_pr, downstream_pr: $downstream_pr, branch: $branch, status: $status}'
    exit 2
fi

cd "$root"
git fetch origin "${TARGET_BRANCH}" >&2

if git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
    echo "create-cherry-pick-draft: skip x2#${upstream_pr} — remote branch ${branch} already exists" >&2
    jq -n \
        --argjson upstream_pr "$upstream_pr" \
        --arg branch "$branch" \
        --arg status "skipped" \
        '{upstream_pr: $upstream_pr, branch: $branch, status: $status}'
    exit 2
fi

ensure_pr_cache_dir "$upstream_pr"
"${SCRIPT_DIR}/fetch-upstream-pr.sh" "$upstream_pr"

meta="$(cat "${cache}/meta.json")"
pr_title="$(echo "$meta" | jq -r '.title')"
pr_url="$(echo "$meta" | jq -r '.url')"
pr_author="$(echo "$meta" | jq -r '.author')"
pr_merged_at="$(echo "$meta" | jq -r '.mergedAt')"

# GitHub PR titles are plain text (no markdown links). Use owner/repo#N so GitHub
# autolinks to the upstream PR (e.g. tier4/autoware_launch.x2#2139).
github_pr_title_max=256
backport_suffix=" (backport ${UPSTREAM_FULL}#${upstream_pr})"
max_title_len=$((github_pr_title_max - ${#backport_suffix}))
truncated_title="$pr_title"
if [[ ${#truncated_title} -gt $max_title_len ]]; then
    truncated_title="${truncated_title:0:max_title_len}..."
fi
draft_title="${truncated_title}${backport_suffix}"

git checkout -B "${branch}" "origin/${TARGET_BRANCH}" >&2

# Configure upstream remote (HTTPS in CI when GH_TOKEN is set).
remote_url="${UPSTREAM_REMOTE_URL}"
if [[ -n ${GH_TOKEN:-} ]]; then
    remote_url="https://x-access-token:${GH_TOKEN}@github.com/${UPSTREAM_FULL}.git"
fi

if git remote get-url "${UPSTREAM_REMOTE}" >/dev/null 2>&1; then
    git remote set-url "${UPSTREAM_REMOTE}" "${remote_url}" >&2
else
    git remote add "${UPSTREAM_REMOTE}" "${remote_url}" >&2
fi

git fetch "${UPSTREAM_REMOTE}" "${TARGET_BRANCH}" >&2
while IFS= read -r sha; do
    [[ -z $sha ]] && continue
    git fetch "${UPSTREAM_REMOTE}" "${sha}" >&2
done < <(jq -r '.[].sha' "${cache}/commits.json")

conflict_file="${cache}/conflicts.txt"
: >"$conflict_file"
failed_sha=""
had_conflict=false

mapfile -t shas < <(jq -r '.[].sha' "${cache}/commits.json")
for sha in "${shas[@]}"; do
    echo "create-cherry-pick-draft: cherry-picking ${sha}..." >&2
    if git cherry-pick -x "$sha"; then
        continue
    fi
    had_conflict=true
    failed_sha="$sha"
    git diff --name-only --diff-filter=U | tee -a "$conflict_file"
    git add -u
    GIT_EDITOR=true git cherry-pick --continue
    break
done

mapfile -t conflict_files < <(sort -u "$conflict_file" 2>/dev/null || true)

git push -u origin "HEAD:${branch}" >&2

conflict_flag="no"
conflict_section="No conflicts."
if $had_conflict; then
    conflict_flag="yes"
    conflict_section="Cherry-pick stopped at \`${failed_sha}\` with unresolved conflict markers in:"
    for f in "${conflict_files[@]}"; do
        [[ -n $f ]] || continue
        conflict_section="${conflict_section}
- \`${f}\`"
    done
    conflict_section="${conflict_section}

Conflict markers are present in the committed files and require agent resolution."
fi

body_file="$(mktemp)"
{
    echo "## Upstream PR"
    echo
    echo "- **PR**: [${upstream_ref}#${upstream_pr}](${pr_url})"
    echo "- **Title**: ${pr_title}"
    echo "- **Author**: ${pr_author}"
    echo "- **Merged at**: ${pr_merged_at}"
    echo "- **Downstream target branch**: \`${TARGET_BRANCH}\`"
    echo
    echo "## Summary"
    echo "- Cherry-picked from: ${upstream_ref}#${upstream_pr}"
    echo "- Upstream PR: ${pr_url}"
    echo "- Target branch: ${TARGET_BRANCH}"
    echo
    echo "## Conflict"
    echo "- conflict: ${conflict_flag}"
    if $had_conflict; then
        echo "- failed_sha: \`${failed_sha}\`"
    fi
    echo
    echo "## Conflict Resolution Details"
    echo "${conflict_section}"
    echo
    echo "## Notes"
    if $had_conflict; then
        echo "- Draft PR created with conflict markers; agent should resolve per auto-cherry-pick-handler SKILL.md."
    else
        echo "- Naive cherry-pick succeeded; review and mark ready for review when validated."
    fi
    echo
    echo "## Labels"
    echo "- ${PR_LABEL}"
} >"$body_file"

downstream_pr="$(gh pr create \
    --repo "${DOWNSTREAM_FULL}" \
    --base "${TARGET_BRANCH}" \
    --head "${branch}" \
    --title "${draft_title}" \
    --body-file "$body_file" \
    --draft \
    --label "${PR_LABEL}")"

rm -f "$body_file"

# gh pr create prints URL; extract PR number.
downstream_pr_num="${downstream_pr##*/}"

echo "create-cherry-pick-draft: created draft PR #${downstream_pr_num} for x2#${upstream_pr}" >&2

jq -n \
    --argjson upstream_pr "$upstream_pr" \
    --argjson downstream_pr "$downstream_pr_num" \
    --arg branch "$branch" \
    --argjson conflict "$had_conflict" \
    --arg failed_sha "$failed_sha" \
    --argjson conflict_files "$(printf '%s\n' "${conflict_files[@]}" | jq -R -s 'split("\n") | map(select(length>0))')" \
    --arg status "created" \
    '{
      upstream_pr: $upstream_pr,
      downstream_pr: $downstream_pr,
      branch: $branch,
      conflict: $conflict,
      conflict_files: $conflict_files,
      failed_sha: (if $failed_sha == "" then null else $failed_sha end),
      status: $status
    }'
