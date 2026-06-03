# Sub-agent prompt — one cherry-pick PR (worktree required)

Copy when launching a Task sub-agent for **multi-PR backlog** mode. Each sub-agent handles **exactly one** downstream PR.

---

## Task

Process **one** downstream cherry-pick PR for `tier4/autoware_launch.xx1` using `.cursor/skills/auto-cherry-pick-handler/SKILL.md`.

| Field         | Value                                    |
| ------------- | ---------------------------------------- |
| Downstream PR | `#<DOWNSTREAM_PR>` (e.g. #1992)          |
| Upstream PR   | `tier4/autoware_launch.x2#<UPSTREAM_PR>` |

## Isolation rules

1. **Never** edit git state on the parent repo root checkout.
2. All git edits in `worktrees/pr-<DOWNSTREAM_PR>/` only.
3. Resolve conflicts in the worktree before returning blocked.
4. `remove-worktree.sh --pr <DOWNSTREAM_PR> --upstream-pr <UPSTREAM_PR>` when done.

## Execution rules

- Run **Phases 0–6 from SKILL.md** in this session; do not skip because a worktree or `.cache/` already exists.
- Do **not** infer PR number or pipeline state from terminal history — use the `DOWNSTREAM_PR` / `UPSTREAM_PR` values passed in this prompt.

---

## Commands

```bash
./.cursor/skills/auto-cherry-pick-handler/scripts/sync-tier4-main.sh
./.cursor/skills/auto-cherry-pick-handler/scripts/run-pr.sh <DOWNSTREAM_PR>
eval "$(./.cursor/skills/auto-cherry-pick-handler/scripts/parse-pr.sh <DOWNSTREAM_PR> --export)"
# Fill agent-assessment.md, resolve conflicts
./.cursor/skills/auto-cherry-pick-handler/scripts/commit-cherry-pick-fix.sh --pr <DOWNSTREAM_PR> --upstream-pr "$UPSTREAM_PR"
./.cursor/skills/auto-cherry-pick-handler/scripts/push-cherry-pick-branch.sh --pr <DOWNSTREAM_PR> --upstream-pr "$UPSTREAM_PR"
# Fill pr-comment-report.md
./.cursor/skills/auto-cherry-pick-handler/scripts/post-pr-comment.sh --pr <DOWNSTREAM_PR> --upstream-pr "$UPSTREAM_PR"
./.cursor/skills/auto-cherry-pick-handler/scripts/remove-worktree.sh --pr <DOWNSTREAM_PR> --upstream-pr "$UPSTREAM_PR"
```

---

## Return to parent

```markdown
### PR #<DOWNSTREAM_PR> — tier4/autoware_launch.x2#<UPSTREAM_PR>

- **Status:** done | skipped | blocked
- **Worktree:** worktrees/pr-<DOWNSTREAM_PR>/
- **conflict:** yes | no
- **Summary:** (2–4 sentences)
- **Blockers:** (if blocked)
```

Do **not** process other PRs.
