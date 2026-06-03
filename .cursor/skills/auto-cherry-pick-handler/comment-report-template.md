# Cherry-pick report (agent → PR comment)

Post via `post-pr-comment.sh` after conflict resolution.

## Summary

- **Upstream:** tier4/autoware_launch.x2#<N> — <one-line intent>
- **Downstream PR:** #<downstream_pr> (tier4/autoware_launch.xx1)
- **conflict:** yes / no

## Original upstream changes

What the upstream PR (and linked originals) intended:

-

## Conflicts encountered

| File | Nature | Resolution |
| ---- | ------ | ---------- |
|      |        |            |

If none: _No conflicts._

## Actions taken

What was applied on XX1 (paths, preset renames, edge routing):

-

## Git publish

- **Fix commit:** yes / no (via `commit-cherry-pick-fix.sh`)
- **Merge commit to integrate remote:** yes / no (via `push-cherry-pick-branch.sh`)
- **Force push:** no (mandatory)

## Validation notes

Suggested checks (launch files touched, grep leftovers):

- [ ] No leftover `x2_preset`, `aip_x2_gen2` in changed files
- [ ] `ros2 launch autoware_launch planning_simulator.launch.xml` if launch touched

## References

- Upstream PR: <url>
- Knowledge: [xx1-x2-launch-knowledge-reference.md](docs/xx1-x2-launch-knowledge-reference.md) §8
