#!/usr/bin/env bash
# List open cherry-pick PRs oldest-first.
#
# Usage:
#   list-prs.sh           # one PR number per line
#   list-prs.sh --json    # full JSON array sorted by createdAt

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_gh
require_jq

mode="numbers"
if [[ ${1:-} == "--json" ]]; then
    mode="json"
fi

json="$(gh pr list \
    --repo "${DOWNSTREAM_FULL}" \
    --label "${PR_LABEL}" \
    --state open \
    --limit 100 \
    --json number,title,createdAt,url,headRefName)"

sorted="$(echo "$json" | jq 'sort_by(.createdAt)')"

if [[ $mode == "json" ]]; then
    echo "$sorted"
else
    echo "$sorted" | jq -r '.[].number'
fi
