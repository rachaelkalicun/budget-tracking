#!/usr/bin/env bash

set -euo pipefail

if (( $# > 1 )); then
  printf 'Usage: %s [base-branch]\n' "$0" >&2
  exit 2
fi

base="${1:-master}"
if [[ -z "$base" ]]; then
  printf 'Base branch must not be empty.\n' >&2
  exit 2
fi

if ! git check-ref-format --branch "$base" >/dev/null 2>&1; then
  printf 'Base branch must be a valid branch name.\n' >&2
  exit 2
fi

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  printf 'Run this helper from inside a Git worktree.\n' >&2
  exit 1
fi

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

branch="$(git symbolic-ref --quiet --short HEAD || true)"
if [[ -z "$branch" ]]; then
  printf 'Refusing to synchronize a detached HEAD; use a named issue branch.\n' >&2
  exit 1
fi

if [[ "$branch" == "master" || "$branch" == "$base" ]]; then
  printf 'Refusing to synchronize while on base branch %s.\n' "$branch" >&2
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  printf 'Remote origin is required to fetch the current base.\n' >&2
  exit 1
fi

if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
  printf 'Working tree is not clean; commit or otherwise resolve issue-branch changes before synchronization.\n' >&2
  exit 1
fi

printf 'Fetching origin/%s...\n' "$base"
git fetch --prune origin "$base"

base_ref="refs/remotes/origin/$base"
if ! git rev-parse --verify "$base_ref^{commit}" >/dev/null 2>&1; then
  printf 'Fetched origin/%s, but the remote base commit could not be resolved.\n' "$base" >&2
  exit 1
fi

base_sha="$(git rev-parse --verify "$base_ref^{commit}")"
before_sha="$(git rev-parse HEAD)"
printf 'Fetched origin/%s at %s.\n' "$base" "$base_sha"

if git merge-base --is-ancestor "$base_ref" HEAD; then
  printf '%s already contains origin/%s; no synchronization needed.\n' "$branch" "$base"
  exit 0
fi

if git merge-base --is-ancestor HEAD "$base_ref"; then
  printf 'Fast-forwarding %s to origin/%s...\n' "$branch" "$base"
  git merge --ff-only "$base_ref"
  printf 'Synchronized %s to %s.\n' "$branch" "$base_sha"
  exit 0
fi

printf 'Merging origin/%s into %s...\n' "$base" "$branch"
set +e
git merge --no-edit "$base_ref"
merge_status=$?
set -e

if (( merge_status == 0 )); then
  printf 'Merged origin/%s into %s.\n' "$base" "$branch"
  exit 0
fi

if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
  if git merge --abort; then
    after_sha="$(git rev-parse HEAD)"
    if [[ "$after_sha" == "$before_sha" && -z "$(git status --porcelain --untracked-files=all)" ]]; then
      printf 'Merge conflict; merge aborted and %s was restored at %s.\n' "$branch" "$before_sha" >&2
    else
      printf 'Merge conflict; merge was aborted, but inspect the issue branch before continuing.\n' >&2
    fi
  else
    printf 'Merge conflict; automatic abort failed. Resolve or abort the merge manually; no reset was attempted.\n' >&2
  fi
else
  printf 'Merge failed before a merge state was created; %s remains at %s.\n' "$branch" "$before_sha" >&2
fi

exit "$merge_status"
