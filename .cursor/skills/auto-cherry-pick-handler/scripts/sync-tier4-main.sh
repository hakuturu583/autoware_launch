#!/usr/bin/env bash
# Fetch and fast-forward local tier4/main from origin.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

root="$(repo_root)"
cd "$root"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "warning: working tree has uncommitted changes" >&2
fi

git fetch origin "${TARGET_BRANCH}"
git checkout "${TARGET_BRANCH}"
git pull --ff-only origin "${TARGET_BRANCH}"

echo "sync-tier4-main: on $(git branch --show-current) @ $(git rev-parse --short HEAD)"
