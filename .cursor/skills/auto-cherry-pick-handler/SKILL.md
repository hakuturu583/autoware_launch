---
name: auto-cherry-pick-handler
description: Processes one autoware_launch.xx1 cherry-pick PR (label cherry-pick from x2) per invocation, porting from tier4/autoware_launch.x2. Always runs Phases 0–6 from scripts (never infers PR/state from terminal history). Gathers context and runs git worktrees; agent resolves conflicts using launch knowledge reference. Use for a single PR, the oldest open cherry-pick PR, or explicit multi-PR backlog with sub-agents.
---

# Auto Cherry-Pick Handler

Resolve and update open **downstream cherry-pick PRs** on `tier4/autoware_launch.xx1` (`tier4/main`), sourcing changes from `tier4/autoware_launch.x2`.

**Knowledge:** [docs/xx1-x2-launch-knowledge-reference.md](docs/xx1-x2-launch-knowledge-reference.md) (read §8 before editing).

## Core principle

**Scripts gather context and run git; the agent judges.** The queue is open **PRs** labeled `cherry-pick from x2` (e.g. PR #1992 on branch `cherry-pick/x2-2122`).

## Agent execution rules (mandatory)

**Follow this skill and run its scripts — do not infer state from elsewhere.**

| Do                                                                      | Don't                                                                        |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Execute **Phases 0 → 6 in order** on every invocation                   | Skip phases because a terminal, worktree, or `.cache/` folder already exists |
| Select the PR from the **user message** or `list-prs.sh \| head -1`     | Guess a PR from terminal output, open terminal tabs, or prior chat context   |
| Run `sync-tier4-main.sh` then `run-pr.sh` **in this session**           | Assume the user already ran the pipeline correctly                           |
| Read `.cache/pr-<UPSTREAM_PR>/` **after** `run-pr.sh` finishes          | Treat stale cache from an earlier run as current                             |
| Use `$CHERRY_PICK_WORKTREE` from `parse-pr.sh --export` / script output | Edit the main repo checkout                                                  |

When the user says "run the workflow" / "cherry-pick" with **no PR number**, run `list-prs.sh`, take the **first line**, then proceed. When they name a PR (e.g. "PR 1992"), use that number only.

**Terminal history is not authoritative.** The user may run scripts independently; your job is still to execute the full workflow defined here.

## Default scope — one PR per invocation

**Each skill run processes exactly one downstream cherry-pick PR end-to-end** (Phases 0–6), then stops.

| User input                  | PR selected                                                                    |
| --------------------------- | ------------------------------------------------------------------------------ |
| Names a PR (e.g. "PR 1992") | That PR only                                                                   |
| No PR named                 | **Oldest** open PR with label `cherry-pick from x2` (`list-prs.sh \| head -1`) |

**Do not** automatically loop through multiple PRs unless the user **explicitly** requests a backlog run.

---

## Queue

```bash
./.cursor/skills/auto-cherry-pick-handler/scripts/list-prs.sh
```

| User says                                  | You do                                     |
| ------------------------------------------ | ------------------------------------------ |
| "cherry-pick" / "process next cherry-pick" | **One PR** — oldest from `list-prs.sh`     |
| "cherry-pick PR 1992"                      | **One PR** — `#1992` only                  |
| "process the full backlog"                 | **Multi-PR mode** — see § Multi-PR backlog |

---

## Git history policy

If push is rejected because `origin` has commits you lack, `push-cherry-pick-branch.sh` runs `git merge origin/cherry-pick/x2-<N>` (merge commit) and pushes again — **no force, no rebase**.

## Worktree isolation (mandatory)

| Rule                           | Detail                                                                    |
| ------------------------------ | ------------------------------------------------------------------------- |
| One worktree per downstream PR | `worktrees/pr-<N>/` on branch `cherry-pick/x2-<upstream_pr>`              |
| Checkout                       | Uses `origin/cherry-pick/x2-<upstream>` when the PR branch already exists |
| All git edits                  | Only inside `CHERRY_PICK_WORKTREE`                                        |
| Never                          | Cherry-pick / commit / rebase on the main repo checkout                   |
| Cleanup                        | `remove-worktree.sh --pr <N>` after PR comment is posted                  |

---

## Quick start — default (single PR)

Run these steps **every time** this skill is invoked (single-PR mode):

```bash
cd /path/to/autoware_launch.xx1

# Phase 0 — preconditions (gh auth, jq, stash WIP if needed)

# Phase 1
./.cursor/skills/auto-cherry-pick-handler/scripts/sync-tier4-main.sh

# Phase 2 — select PR (script output is the source of truth)
# User named a PR → pr=<number>
# Otherwise → pr=$(./.cursor/skills/auto-cherry-pick-handler/scripts/list-prs.sh | head -1)
eval "$(./.cursor/skills/auto-cherry-pick-handler/scripts/parse-pr.sh "$pr" --export)"

# Phase 3
./.cursor/skills/auto-cherry-pick-handler/scripts/run-pr.sh "$pr"
```

Then complete **Phases 4–6** (agent) below. **Stop** after this PR.

---

## Multi-PR backlog (opt-in only)

Use only when the user explicitly asks to process **multiple** PRs.

1. Parent runs `init-backlog.sh --mode live` once.
2. For each pending PR in `manifest.json`, launch **one** Task sub-agent with [subagent-prompt.md](subagent-prompt.md).
3. Parent runs `record-backlog-item.sh --pr <N>` per return.
4. Parent runs `finalize-backlog.sh`.

**Do not** chain multiple `run-pr.sh` calls in one parent session without sub-agents.

---

## Phase 0 — Preconditions

- `gh auth status` (repo scope)
- `jq` installed
- Read knowledge reference §8 when touching launch files
- Stash WIP before `sync-tier4-main.sh`

---

## Phase 1 — Sync downstream

```bash
./.cursor/skills/auto-cherry-pick-handler/scripts/sync-tier4-main.sh
```

---

## Phase 2 — Select PR

```bash
eval "$(./.cursor/skills/auto-cherry-pick-handler/scripts/parse-pr.sh <downstream_pr> --export)"
```

Exports: `DOWNSTREAM_PR`, `UPSTREAM_PR`, `UPSTREAM_REF`, `HEAD_REF`, `TARGET_BRANCH`.

Upstream PR is parsed from `headRefName` (`cherry-pick/x2-<N>`), PR body link, or title.

---

## Phase 3 — Automated pipeline

`run-pr.sh <downstream_pr>` runs:

1. `setup-worktree.sh` — checkout existing PR branch when present
2. `try-cherry-pick.sh` — only if branch has no commits yet
3. `update-branch-with-main.sh` — rebase onto `origin/tier4/main`
4. `gather-context.sh` — cache under `.cache/pr-<upstream_pr>/`

---

## Phase 4 — Agent: understand + fix (required)

Read: `.cache/pr-<UPSTREAM_PR>/context-bundle.md`  
Fill: `.cache/pr-<UPSTREAM_PR>/agent-assessment.md`

**No scripted path mapping.** Use:

1. PR descriptions + linked PRs + `diff.patch`
2. [docs/xx1-x2-launch-knowledge-reference.md](docs/xx1-x2-launch-knowledge-reference.md) §8
3. **Explore `$CHERRY_PICK_WORKTREE`** — list/grep/read files; confirm XX1 targets before editing

Resolve conflicts in the worktree, then publish with **fix commit + merge-only push** (see Git history policy):

```bash
./.cursor/skills/auto-cherry-pick-handler/scripts/commit-cherry-pick-fix.sh --pr <DOWNSTREAM_PR> --upstream-pr <UPSTREAM_PR>
./.cursor/skills/auto-cherry-pick-handler/scripts/push-cherry-pick-branch.sh --pr <DOWNSTREAM_PR> --upstream-pr <UPSTREAM_PR>
```

---

## Phase 5 — Agent: report + comment

Fill: `.cache/pr-<UPSTREAM_PR>/pr-comment-report.md`

```bash
./.cursor/skills/auto-cherry-pick-handler/scripts/post-pr-comment.sh --pr <DOWNSTREAM_PR> --upstream-pr <UPSTREAM_PR>
```

---

## Phase 6 — Cleanup

```bash
./.cursor/skills/auto-cherry-pick-handler/scripts/remove-worktree.sh --pr <DOWNSTREAM_PR> --upstream-pr <UPSTREAM_PR>
```

---

## Script reference

| Script                                                               | Purpose                                               |
| -------------------------------------------------------------------- | ----------------------------------------------------- |
| `list-prs.sh`                                                        | Open cherry-pick PRs, oldest first                    |
| `parse-pr.sh`                                                        | Upstream PR from downstream PR metadata               |
| `run-pr.sh`                                                          | Full automated chain for **one** PR                   |
| `gather-context.sh`                                                  | Cache upstream + downstream PR context                |
| `try-cherry-pick.sh`                                                 | Naive cherry-pick if branch empty                     |
| `update-branch-with-main.sh`                                         | Rebase onto latest main                               |
| `post-pr-comment.sh`                                                 | Post `pr-comment-report.md` on downstream PR          |
| `commit-cherry-pick-fix.sh`                                          | Stage resolved files; new fix commit (no amend/reset) |
| `push-cherry-pick-branch.sh`                                         | Push without force; merge `origin/<branch>` if behind |
| `init-backlog.sh` / `record-backlog-item.sh` / `finalize-backlog.sh` | Multi-PR backlog                                      |

---

## Additional resources

- [subagent-prompt.md](subagent-prompt.md)
- [docs/README.md](docs/README.md)
- [assessment-template.md](assessment-template.md)
- [comment-report-template.md](comment-report-template.md)
