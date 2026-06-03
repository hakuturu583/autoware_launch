#!/usr/bin/env bash
# Fetch upstream PR metadata into .cache/pr-<N>/.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"

require_jq
if [[ -z ${GH_TOKEN:-} ]]; then
    require_gh
fi

pr="${1:?usage: fetch-upstream-pr.sh <upstream_pr_number>}"
cache="$(pr_cache_dir "$pr")"
ensure_pr_cache_dir "$pr"

meta="$(gh pr view "$pr" --repo "${UPSTREAM_FULL}" \
    --json number,title,body,url,mergeCommit,commits,files,mergedAt,author)"

echo "$meta" | jq '{number, title, url, body, mergedAt, author: .author.login, mergeCommit: .mergeCommit.oid}' \
    >"${cache}/meta.json"

echo "$meta" | jq '[.commits[] | {sha: .oid, message: .messageHeadline}]' \
    >"${cache}/commits.json"

echo "$meta" | jq '[.files[] | {path: .path, additions: .additions, deletions: .deletions}]' \
    >"${cache}/files.json"

gh pr diff "$pr" --repo "${UPSTREAM_FULL}" >"${cache}/diff.patch"

echo "fetch-upstream-pr: cached to ${cache}"
echo "  files: $(jq 'length' "${cache}/files.json")"
echo "  commits: $(jq 'length' "${cache}/commits.json")"
echo "  diff lines: $(wc -l <"${cache}/diff.patch")"
