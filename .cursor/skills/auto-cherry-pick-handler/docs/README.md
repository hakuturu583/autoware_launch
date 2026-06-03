# Cursor docs — Autoware launch (XX1 / X2)

Agent-oriented notes for this workspace. Read these before cherry-picking PRs or editing launch/config in the launch repos below.

## Index

| Document                                                                     | Purpose                                                                                                                 |
| ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| [xx1-x2-launch-knowledge-reference.md](xx1-x2-launch-knowledge-reference.md) | Systematic XX1 vs X2 differences, launch workflows, edge Jetson three-repo model, cherry-pick playbook, file-path index |

## Skill automation

Scripts and workflow: [../SKILL.md](../SKILL.md) (`auto-cherry-pick-handler`).

**Default:** one cherry-pick **PR** per skill invocation. The agent selects the PR via `list-prs.sh` (or a user-named number) and runs **Phases 0–6 from scripts** — never from terminal history or stale cache. Multi-PR backlog: parent + [subagent-prompt.md](../subagent-prompt.md).

**Publish policy:** `commit-cherry-pick-fix.sh` then `push-cherry-pick-branch.sh`. Never force-push or `reset --soft` on published cherry-pick branches; if `origin` diverged, the push script adds a **merge commit** only. Stale worktrees are pruned in `setup-worktree.sh` / `remove-worktree.sh`.

## When to open the reference

- Porting a PR from `autoware_launch.x2` → `autoware_launch.xx1`
- Porting edge Jetson changes from X2 → XX1 gen2 external repo
- Changing `sensor_model`, presets, trajectory follower, or AIP sensing
- Adding launch files or `package.xml` exec_depends
- Debugging launch argument / topic namespace mismatches between vehicles

## Repo paths (workspace)

| Repo                 | Path                                  | Role                                                                                                |
| -------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------- |
| XX1 launch           | `autoware_launch.xx1/`                | XX1 vehicle Autoware launch + config (no in-tree edge Jetson yet)                                   |
| X2 launch            | `autoware_launch.x2/`                 | X2 vehicle Autoware launch + in-tree `edge_auto_jetson_launch/`                                     |
| XX1 gen2 edge Jetson | `edge_auto_jetson_launch.xx1_gen2.0/` | **Production** XX1 camera / 2D perception / TLR on Jetson (external until merged into XX1 monorepo) |

**Edge Jetson XX1 production entrances** (not `edge_auto_jetson.launch.xml`):

- `edge_auto_jetson_launch.xx1_gen2.0/edge_auto_jetson_launch/launch/perception_multiple.launch.xml`
- `edge_auto_jetson_launch.xx1_gen2.0/edge_auto_jetson_launch/launch/tlr/jetson_tlr.launch.xml`

See reference §7 for full edge cherry-pick routing.
