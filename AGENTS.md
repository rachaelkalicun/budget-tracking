# Budget-tracking agent policy

This is the authoritative repository policy for agent-assisted work. Keep
repository-wide invariants here and put subject-specific procedures in the
[issue-delivery skill](skills/ship-issue/SKILL.md), the
[linked-worktree adapter](skills/budget-tracking-worktree/SKILL.md), and the
[adversarial review checkpoint](docs/engineering/adversarial_review_checkpoint.md).
Repository-owned skills under `skills/**` override generic or global versions
for this repository.

## Scope and authority

- A GitHub issue defines the approved objective, acceptance criteria, and
  non-goals. Keep every change inside that issue's scope.
- Read the issue and its comments before editing. Do not invent product
  behavior that an issue deliberately leaves for real-use investigation.
- If a persistent rule belongs to a subject-specific document, put it there
  and link to it instead of duplicating it here.

## Architecture

- This remains a small local-first Ruby tool unless an explicit later issue
  changes that decision.
- Use the Ruby version in `.ruby-version` (currently Ruby 3.4.4) and keep
  Minitest as the test framework.
- Prefer the existing Ruby/CSV modules and small, deterministic changes over
  speculative services, frameworks, databases, Rails rewrites, or hosted
  architecture.
- Do not introduce direct bank connections, Plaid, hosted financial storage,
  or AI transaction categorization unless a future issue explicitly allows
  it.

## Financial privacy and secrets

Agents must never read, print, copy into prompts or logs, commit, or turn into
fixtures:

- real files under `data/`;
- generated private outputs under `output/`;
- real account numbers, last-four digits, balances, statements, or
  transaction histories;
- Google credentials, OAuth/API tokens, API keys, or downloaded credential
  files;
- private account configuration introduced by a later issue; or
- private Google Sheet contents.

Use synthetic or deliberately sanitized fixtures only. Structural inspection
of a real export is allowed only when the ticket or user explicitly requires
it, and any committed fixture must replace private values with synthetic
ones. Logs and errors may expose safe file names, structural headers, counts,
reason codes, and safe account labels when needed, but must not dump full
transaction rows. Never commit credentials or private local configuration.
Keep raw `data/` and generated `output/` ignored; future account-configuration
and Google-integration issues own the exact paths for those files.

## Financial integrity

- A passing test is not permission to change financial semantics merely to
  make the test pass. Investigate code behavior, source semantics, and issue
  policy first.
- Never silently drop, duplicate, reinterpret, or guess ambiguous financial
  transactions. Route ambiguous rows, duplicate candidates, gift-card cases,
  HSA actions, and Google Sheet matches to explicit review when the governing
  issue requires it.
- Use the precise money representation established by the relevant issue;
  do not introduce new floating-point assumptions into aggregation or
  reconciliation work.
- Preserve account/source identity separately from parser/export-format
  identity. Closed or paused accounts must retain historical import ability.
- External writes, especially Google Sheets writes, must be explicit,
  validated immediately before mutation, idempotent, and safe to rerun.

## Git and delivery

- One finite issue normally uses one `codex/issue-<number>-<slug>` branch and
  one ready-for-review PR targeting `master`.
- Human review and merge are mandatory. Agents never merge PRs.
- Use `Closes #<number>` only when all acceptance criteria are complete;
  otherwise use `Refs #<number>`.
- Preserve unrelated local changes and untracked files. Never discard or
  overwrite unclear work, rewrite published branch history, or use
  destructive Git commands without explicit authorization.

## Current-master and parallel-work safety

- Start or resume from a freshly fetched current `origin/master`.
- Use the documented merge-based helper at
  `script/codex/sync-base.sh`; do not rebase published Codex branches.
- Synchronize before implementation or resumed review-fix work, again before
  final validation, and once more after final validation.
- A PR is not ready until the latest fetched `origin/master` is an ancestor
  of the issue branch `HEAD` and there are no unresolved or known merge
  conflicts.
- If new upstream commits touch the issue's behavior or files, inspect
  semantic overlap even when Git reports a clean merge and rerun affected
  checks.

## Validation

- Run focused Minitest checks while iterating and broader direct checks in
  proportion to changed behavior and risk.
- Until issue #8 establishes a better documented command, the baseline is
  `bundle exec rake test` (the default Rake test task).
- Report exact commands and whether each passed, failed, was blocked, or was
  intentionally not applicable. Never claim a check passed if it did not run.
