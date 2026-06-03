#!/usr/bin/env bash
# Parse a downstream cherry-pick PR into upstream PR metadata.
#
# Usage:
#   parse-pr.sh <downstream_pr_number>
#   parse-pr.sh <downstream_pr_number> --export
#   parse-pr.sh <downstream_pr_number> --json

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_gh
require_jq

downstream_pr="${1:?usage: parse-pr.sh <downstream_pr_number> [--export|--json]}"
mode="text"
if [[ ${2:-} == "--export" ]]; then
    mode="export"
elif [[ ${2:-} == "--json" ]]; then
    mode="json"
fi

data="$(gh pr view "$downstream_pr" --repo "${DOWNSTREAM_FULL}" \
    --json number,title,body,headRefName,baseRefName,url)"
title="$(echo "$data" | jq -r '.title')"
body="$(echo "$data" | jq -r '.body')"
head_ref="$(echo "$data" | jq -r '.headRefName')"
pr_url="$(echo "$data" | jq -r '.url')"

upstream_owner=""
upstream_repo=""
upstream_pr=""

# Branch: cherry-pick/x2-<upstream_pr>
if [[ $head_ref =~ ^${BRANCH_PREFIX}-([0-9]+)$ ]]; then
    upstream_pr="${BASH_REMATCH[1]}"
    upstream_owner="${UPSTREAM_OWNER}"
    upstream_repo="${UPSTREAM_REPO}"
elif [[ $head_ref =~ x2-([0-9]+)$ ]]; then
    upstream_pr="${BASH_REMATCH[1]}"
    upstream_owner="${UPSTREAM_OWNER}"
    upstream_repo="${UPSTREAM_REPO}"
fi

# Body: Upstream PR link
if [[ -z $upstream_pr && $body =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    upstream_owner="${BASH_REMATCH[1]}"
    upstream_repo="${BASH_REMATCH[2]}"
    upstream_pr="${BASH_REMATCH[3]}"
fi

# Title: feat: foo (backport tier4/autoware_launch.x2#N)
if [[ -z $upstream_pr && $title =~ \(backport\ ([^#]+)#([0-9]+)\)$ ]]; then
    upstream_ref="${BASH_REMATCH[1]}"
    upstream_pr="${BASH_REMATCH[2]}"
    if [[ $upstream_ref == */* ]]; then
        upstream_owner="${upstream_ref%%/*}"
        upstream_repo="${upstream_ref#*/}"
    else
        upstream_owner="${UPSTREAM_OWNER}"
        upstream_repo="${UPSTREAM_REPO}"
    fi
fi

# Title (legacy): Cherry-pick: [tier4/autoware_launch.x2#N]:
if [[ -z $upstream_pr && $title =~ \[([^#]+)#([0-9]+)\] ]]; then
    upstream_ref="${BASH_REMATCH[1]}"
    upstream_pr="${BASH_REMATCH[2]}"
    if [[ $upstream_ref == */* ]]; then
        upstream_owner="${upstream_ref%%/*}"
        upstream_repo="${upstream_ref#*/}"
    else
        upstream_owner="${UPSTREAM_OWNER}"
        upstream_repo="${UPSTREAM_REPO}"
    fi
fi

if [[ -z $upstream_pr ]]; then
    echo "error: cannot parse upstream PR from downstream PR #${downstream_pr}" >&2
    echo "  tried headRefName=${head_ref}, body link, title" >&2
    exit 1
fi

upstream_ref="${upstream_owner}/${upstream_repo}"

result="$(jq -n \
    --argjson downstream_pr "$downstream_pr" \
    --arg upstream_owner "$upstream_owner" \
    --arg upstream_repo "$upstream_repo" \
    --argjson upstream_pr "$upstream_pr" \
    --arg upstream_ref "$upstream_ref" \
    --arg target_branch "${TARGET_BRANCH}" \
    --arg pr_title "$title" \
    --arg head_ref "$head_ref" \
    --arg pr_url "$pr_url" \
    '{
    downstream_pr: $downstream_pr,
    upstream_owner: $upstream_owner,
    upstream_repo: $upstream_repo,
    upstream_pr: $upstream_pr,
    upstream_ref: $upstream_ref,
    target_branch: $target_branch,
    pr_title: $pr_title,
    head_ref: $head_ref,
    pr_url: $pr_url
  }')"

case "$mode" in
json)
    echo "$result"
    ;;
export)
    echo "$result" | jq -r '
    "export DOWNSTREAM_PR=\(.downstream_pr)",
    "export UPSTREAM_OWNER=\(.upstream_owner)",
    "export UPSTREAM_REPO=\(.upstream_repo)",
    "export UPSTREAM_PR=\(.upstream_pr)",
    "export UPSTREAM_REF=\(.upstream_ref)",
    "export TARGET_BRANCH=\(.target_branch)",
    "export PR_TITLE=\(.pr_title | @sh)",
    "export HEAD_REF=\(.head_ref | @sh)",
    "export DOWNSTREAM_PR_URL=\(.pr_url | @sh)"
  '
    ;;
text)
    echo "downstream_pr=${downstream_pr}"
    echo "upstream_ref=${upstream_ref}"
    echo "upstream_pr=${upstream_pr}"
    echo "head_ref=${head_ref}"
    echo "target_branch=${TARGET_BRANCH}"
    echo "pr_title=${title}"
    ;;
esac
