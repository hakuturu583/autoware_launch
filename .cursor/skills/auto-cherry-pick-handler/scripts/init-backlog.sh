#!/usr/bin/env bash
# Initialize a backlog run: list all open cherry-pick PRs and create progress tracker.
#
# Usage:
#   init-backlog.sh [--mode dry-run|live]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_gh
require_jq

mode="live"
if [[ ${1:-} == "--mode" && -n ${2:-} ]]; then
    mode="$2"
fi

run_dir="${CACHE_ROOT}/backlog-run"
mkdir -p "$run_dir"

json="$("${SCRIPT_DIR}/list-prs.sh" --json)"
count="$(echo "$json" | jq 'length')"

echo "$json" | jq --arg mode "$mode" --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '[.[] | {downstream_pr: .number, title: .title, url: .url, createdAt: .createdAt, status: "pending"}] | {
    mode: $mode,
    started_at: $started,
    total: length,
    prs: .
  }' >"${run_dir}/manifest.json"

{
    echo "# Cherry-pick backlog run"
    echo ""
    echo "- **Mode:** ${mode}"
    echo "- **Started:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "- **Total PRs:** ${count}"
    echo ""
    echo "| PR | Title | Status | Summary |"
    echo "|----|-------|--------|---------|"
    echo "$json" | jq -r '.[] | "| #\(.number) | \(.title | gsub("\\|";"/")) | pending | |"'
} >"${run_dir}/progress.md"

echo "init-backlog: ${count} PR(s) → ${run_dir}/manifest.json"
echo "init-backlog: process ONE PR per sub-agent (see subagent-prompt.md); do not loop in a single agent"
jq -r '.prs[] | "  #\(.downstream_pr)  \(.title)"' "${run_dir}/manifest.json"
