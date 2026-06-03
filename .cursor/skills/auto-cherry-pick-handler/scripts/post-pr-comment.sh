#!/usr/bin/env bash
# Post agent-written report as a comment on the downstream cherry-pick PR.
#
# Usage:
#   post-pr-comment.sh --pr <downstream_pr> [--upstream-pr <M>] [--body-file path]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_gh
require_jq

upstream_pr=""
downstream_pr=""
body_file=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --upstream-pr)
        upstream_pr="$2"
        shift 2
        ;;
    --pr)
        downstream_pr="$2"
        shift 2
        ;;
    --body-file)
        body_file="$2"
        shift 2
        ;;
    *)
        echo "error: unknown argument $1" >&2
        exit 1
        ;;
    esac
done

[[ -n $downstream_pr ]] || {
    echo "usage: post-pr-comment.sh --pr <downstream_pr> [--upstream-pr <M>] [--body-file path]" >&2
    exit 1
}

if [[ -z $upstream_pr ]]; then
    eval "$("${SCRIPT_DIR}/parse-pr.sh" "$downstream_pr" --export)"
    upstream_pr="$UPSTREAM_PR"
fi

cache="$(pr_cache_dir "$upstream_pr")"
body_file="${body_file:-${cache}/pr-comment-report.md}"

if [[ ! -f $body_file ]]; then
    echo "error: body file not found: ${body_file}" >&2
    exit 1
fi

gh pr comment "$downstream_pr" --repo "${DOWNSTREAM_FULL}" --body-file "$body_file"
echo "post-pr-comment: commented on ${DOWNSTREAM_FULL}#${downstream_pr}"
