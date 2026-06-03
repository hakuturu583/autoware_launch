#!/usr/bin/env bash
# Mark one PR done/skipped/blocked in the backlog run tracker.
#
# Usage:
#   record-backlog-item.sh --pr <N> --status <done|skipped|blocked> \
#     [--summary "text"] [--artifact "path or url"]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_jq

downstream_pr=""
status=""
summary=""
artifact=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --pr)
        downstream_pr="$2"
        shift 2
        ;;
    --status)
        status="$2"
        shift 2
        ;;
    --summary)
        summary="$2"
        shift 2
        ;;
    --artifact)
        artifact="$2"
        shift 2
        ;;
    *)
        echo "error: unknown argument $1" >&2
        exit 1
        ;;
    esac
done

if [[ -z $downstream_pr || -z $status ]]; then
    echo "usage: record-backlog-item.sh --pr <N> --status <done|skipped|blocked> [--summary text] [--artifact path]" >&2
    exit 1
fi

run_dir="${CACHE_ROOT}/backlog-run"
manifest="${run_dir}/manifest.json"

if [[ ! -f $manifest ]]; then
    echo "error: run init-backlog.sh first" >&2
    exit 1
fi

finished="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
tmp="$(mktemp)"
jq --argjson num "$downstream_pr" --arg st "$status" --arg sum "$summary" --arg art "$artifact" --arg fin "$finished" \
    '(.prs[] | select(.downstream_pr == $num)) |= . + {
    status: $st,
    summary: $sum,
    artifact: $art,
    finished_at: $fin
  }' "$manifest" >"$tmp"
mv "$tmp" "$manifest"

{
    echo "# Cherry-pick backlog run"
    echo ""
    jq -r '"- **Mode:** \(.mode)\n- **Started:** \(.started_at)\n- **Total:** \(.total)"' "$manifest"
    done_count="$(jq '[.prs[] | select(.status == "done")] | length' "$manifest")"
    pending_count="$(jq '[.prs[] | select(.status == "pending")] | length' "$manifest")"
    echo "- **Done:** ${done_count} | **Pending:** ${pending_count}"
    echo ""
    echo "| PR | Title | Status | Summary | Artifact |"
    echo "|----|-------|--------|---------|----------|"
    jq -r '.prs[] | "| #\(.downstream_pr) | \(.title | gsub("\\|";"/")) | \(.status) | \(.summary // "" | gsub("\\|";"/")) | \(.artifact // "") |"' "$manifest"
} >"${run_dir}/progress.md"

remaining="$(jq '[.prs[] | select(.status == "pending")] | length' "$manifest")"
echo "record-backlog-item: PR #${downstream_pr} → ${status} (${remaining} pending)"

if [[ $remaining -eq 0 ]]; then
    echo "record-backlog-item: backlog complete — run finalize-backlog.sh"
fi
