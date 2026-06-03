# Agent assessment — tier4/autoware_launch.x2#<PR>

**Downstream PR:** #<downstream_pr> (tier4/autoware_launch.xx1)  
**Assessor:** (agent)  
**Date:**

## 1. Upstream intent (from descriptions, not diff alone)

Summarize what this PR is trying to do. Quote or paraphrase the **PR body** and title.

- Primary PR #<N>:
- Linked / backport PRs (e.g. original when porting a cherry-pick PR):

## 2. Backport chain

| PR  | Role         | Merged? | Notes |
| --- | ------------ | ------- | ----- |
|     | primary      |         |       |
|     | original fix |         |       |

Commits / SHAs referenced in descriptions:

## 3. Applicability to autoware_launch.xx1

Read [docs/xx1-x2-launch-knowledge-reference.md](docs/xx1-x2-launch-knowledge-reference.md) §8.1–§8.2, then **verify in the worktree** (not from scripts):

- [ ] Port to monorepo paths
- [ ] Port to `edge_auto_jetson_launch.xx1_gen2.0` (external)
- [ ] Skip / X2-only (explain)
- [ ] Partial — list files

Worktree notes (paths checked, analogous XX1 files found or missing):

## 4. Conflict forecast

After reading diffs **and** descriptions:

- [ ] Naive cherry-pick likely clean
- [ ] Conflicts expected but **solvable** by agent (describe strategy)
- [ ] Conflicts **heavy** — plan two-commit + draft PR

Per-file notes:

## 5. Port plan

Concrete steps from §8.3 + worktree inspection (which files to touch, skip, or create):

1.
2.

## 6. Outcome recommendation

| Field              | Choice              |
| ------------------ | ------------------- |
| `conflict:`        | yes / no            |
| Confidence         | high / medium / low |
| Needs human review | yes / no            |

**Rationale:**

## 7. Open questions for humans

-
