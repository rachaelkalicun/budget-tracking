# Adversarial review checkpoint

This is a failure-oriented review aid for elevated-risk changes. It is not a
required ceremony for every issue. Apply it when a change touches one or more
of the following:

- transaction inclusion or exclusion semantics that could materially change
  totals;
- duplicate, reconciliation, or automatic row-suppression identity;
- Amazon/card reconciliation or gift-card double-counting policy;
- HSA or investment-action classification with financial-total consequences;
- destructive file or data behavior;
- Google Sheets or another external mutation;
- credentials, tokens, or private financial-data handling;
- persistent transaction state if it is introduced later; or
- parser/schema behavior where silent partial processing could produce
  misleading output.

## Review record

Record the issue, reviewer/date, trigger(s), exact validation commands, and
whether each finding is blocking or an explicit non-blocking follow-up. A
blocking finding must be fixed before push.

## Privacy

- Can logs, errors, fixtures, tests, PR descriptions, or screenshots expose
  private transactions, account identifiers, balances, or credentials?
- Are all committed fixtures synthetic or sufficiently sanitized to publish?
- Are `data/`, `output/`, local account configuration, and downloaded
  credential/token files kept out of the diff?

## Financial integrity

- Can the change silently omit legitimate activity or count one activity
  twice?
- What happens with legitimate repeated same-date, same-merchant,
  same-amount transactions?
- Does account identity remain part of reconciliation wherever necessary?
- Are unknown, malformed, overlapping, or ambiguous cases surfaced rather
  than guessed?
- Can partial input or source-schema drift create apparently complete output?
- Is the money representation precise and consistent with the governing issue?

## External writes and idempotency

- Is the destination validated immediately before mutation?
- Can retrying or rerunning safely produce zero duplicate effects?
- What happens if only part of a multi-step write succeeds?
- Is a read-only or dry-run path available where the governing issue requires
  one?

## Recovery

- Can a failed operation be rerun safely?
- Is there a clear way to inspect what happened without dumping private rows?
- Are source files and generated outputs preserved or recoverable when a
  destructive behavior is involved?

## Decision

State whether the change is safe to push, list any blocking fixes completed,
and record every remaining follow-up with an issue or an explicit owner.
