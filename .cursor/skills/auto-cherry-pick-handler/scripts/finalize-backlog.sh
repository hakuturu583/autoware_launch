#!/usr/bin/env bash
# Write BACKLOG-SUMMARY.md when a backlog run finishes.
#
# Usage:
#   finalize-backlog.sh [--note "stopped early: reason"]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_jq

note=""
if [[ ${1:-} == "--note" ]]; then
    note="$2"
fi

run_dir="${CACHE_ROOT}/backlog-run"
manifest="${run_dir}/manifest.json"

if [[ ! -f $manifest ]]; then
    echo "error: run init-backlog.sh first" >&2
    exit 1
fi

summary="${run_dir}/BACKLOG-SUMMARY.md"
{
    echo "# Backlog run summary"
    echo ""
    echo "**Finished:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    [[ -n $note ]] && echo "**Note:** ${note}"
    echo ""
    cat "${run_dir}/progress.md"
    echo ""
    echo "## Per-PR artifacts"
    echo ""
    jq -r '.prs[] | select(.artifact != null and .artifact != "") |
    "- PR #\(.downstream_pr) (\(.status)): \(.artifact)"' "$manifest"
    echo ""
    echo "## JSON manifest"
    echo ""
    echo '```json'
    jq . "$manifest"
    echo '```'
} >"$summary"

echo "finalize-backlog: ${summary}"
