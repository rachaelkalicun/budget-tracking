---
name: ship-issue
description: Implement one budget-tracking GitHub issue through a privacy-safe, current-master-synchronized branch and ready-for-review PR.
---

# Ship one issue

Use this skill for normal implementation work in this repository. Read
`AGENTS.md` first; it is authoritative for repository-wide policy. Read the
target GitHub issue and all available comments before editing.

## Required workflow

1. Extract the issue objective, acceptance criteria, non-goals, privacy risk,
   financial-integrity risk, and external-write risk. Keep a short working
   checklist so the final report can distinguish complete criteria from
   follow-up.
2. Inspect the checkout, current branch, worktree status, and remotes. Preserve
   unrelated dirty work and untracked files. If this is a linked worktree,
   also follow `skills/budget-tracking-worktree/SKILL.md`.
3. Fetch the current base and create or resume exactly one branch named
   `codex/issue-<number>-<slug>`. Never switch the user's primary checkout
   just to service a linked-worktree task. Synchronize the clean issue branch
   with `script/codex/sync-base.sh` before implementation or resumed review
   fixes.
4. Implement the smallest complete issue scope. Use synthetic or sanitized
   fixtures only, keep parser/export-format identity separate from account
   identity, and do not add behavior reserved for another issue.
5. Run the adversarial checkpoint when the change matches any of its elevated-
   risk triggers. Blocking findings must be fixed before push; record
   non-blocking findings as explicit follow-up.
6. Run focused checks while iterating. Before final validation, synchronize
   again with the current base using the merge-based helper. Inspect semantic
   overlap for any newly merged upstream work and rerun affected checks.
7. Review the final diff for secrets, private financial data, generated files,
   accidental scope expansion, and unresolved merge markers. Run
   `git diff --check` and the risk-appropriate direct tests. At minimum, use
   `bundle exec rake test` unless the repository or issue provides a more
   appropriate command, and report the exact result.
8. After the final validation run, freshly fetch `origin/master` and confirm
   that this fetched base is an ancestor of `HEAD`. If it is not, synchronize
   again, inspect overlap, and rerun affected validation. Do not call the PR
   ready while a conflict is unresolved or the branch is stale.
9. Commit only scoped changes with an issue-aware message. Review the staged
   diff for private data before pushing. Use the repository PR template and
   include exact validation, risk/follow-up, external-write behavior when
   relevant, the correct `Closes`/`Refs` reference, and current-master
   freshness evidence.
10. Push the issue branch and open or update a ready-for-review PR targeting
    `master`. Never merge it. Human review and merge remain required.

## Safety boundaries

- Never use real `data/`, `output/`, account configuration, credentials,
  tokens, or private Google Sheet contents as agent input, logs, fixtures, or
  committed artifacts.
- Do not silently guess at ambiguous financial activity or make a test pass by
  changing financial semantics without understanding the source and issue
  policy.
- Do not stash, reset, delete, rebase, or overwrite unrelated work. Do not
  rewrite published branch history.
- Treat external writes as a separate risk: validate the destination
  immediately before mutation, make the operation explicitly authorized and
  idempotent, and verify the result.

## Handoff report

Report the issue and branch, files changed, acceptance criteria completed or
left as follow-up, exact validation commands and results, privacy/financial-
integrity/external-write risks, current-master ancestry evidence, and any
preserved dirty or ignored private files. Do not include private transaction
values in the report.
