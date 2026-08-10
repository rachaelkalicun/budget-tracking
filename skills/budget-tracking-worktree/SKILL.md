---
name: budget-tracking-worktree
description: Keep budget-tracking issue work safe inside an existing linked Git worktree without touching the primary checkout or private financial files.
---

# Linked-worktree adapter

Apply this adapter only when work is already running in a linked worktree. The
ordinary policy and issue-delivery workflow remain in `AGENTS.md` and
`skills/ship-issue/SKILL.md`.

## Rules

- Never switch branches, clean files, or otherwise operate on the user's
  primary checkout from this worktree.
- Fetch current `origin/master` before creating or resuming an issue branch.
- Use one unique `codex/issue-<number>-<slug>` branch per issue; never check
  the same issue branch out in two worktrees.
- Preserve unrelated dirty work. Prefer a fresh clean worktree rather than
  moving, stashing, resetting, or deleting changes that are not part of the
  issue.
- Treat ignored financial files visible to the worktree as opaque private
  data. Do not inspect them or use them as fixtures or inputs for Codex.
- Use the merge-based `script/codex/sync-base.sh` helper before implementation
  or resumed review-fix work, again before final validation, and in the final
  freshness loop after validation. Do not rebase published issue branches.
- If synchronization conflicts, abort and report the conflict; do not
  auto-resolve semantic overlap.
- Leave the worktree intact for review fixes until the PR is merged. Agents do
  not merge or remove the worktree as part of delivery.
