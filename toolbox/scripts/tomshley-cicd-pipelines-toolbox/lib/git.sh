#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Git helpers for cicd-pipelines toolbox scripts.
# Source this file; do not execute directly.
#
# These are pure git operations — NO auth, NO platform variables.
# Fatal errors call log_fatal (requires lib/log.sh to be sourced first).

# Neutralize LFS so hooks/filters don't block gitflow operations.
# Usage: git_neutralize_lfs
git_neutralize_lfs() {
  git config filter.lfs.smudge "cat"
  git config filter.lfs.clean "cat"
  git config filter.lfs.required false
  rm -f .git/hooks/post-checkout .git/hooks/pre-push .git/hooks/post-commit .git/hooks/post-merge 2>/dev/null || true
  # Reset working tree after LFS filter change (tracked files appear modified)
  git checkout -- . 2>/dev/null || true
}

# Configure git user identity.
# Usage: git_configure_user "user@example.com" "User Name"
git_configure_user() {
  local email="$1"
  local name="$2"
  git config user.email "$email"
  git config user.name "$name"
}

# Fetch all tags from origin.
# Usage: git_fetch_tags
git_fetch_tags() {
  git fetch --tags
}

# Checkout branch and pull with rebase.
# Usage: git_checkout_pull_rebase develop
git_checkout_pull_rebase() {
  local branch="$1"
  git checkout "$branch"
  git pull origin "$branch" --rebase --prune
}

# Checkout branch and pull with fast-forward only.
# Usage: git_checkout_pull_ff "release/0.4.21"
git_checkout_pull_ff() {
  local branch="$1"
  git checkout "$branch"
  git pull origin "$branch" --ff-only --prune
}

# Check if a tag exists locally. Returns 0 if exists, 1 if not.
# Usage: if git_tag_exists "v0.4.21"; then ...
git_tag_exists() {
  local tag="$1"
  git rev-parse "refs/tags/${tag}" >/dev/null 2>&1
}

# Check if a tag exists on the remote. Returns 0 if exists, 1 if not.
# Usage: if git_remote_tag_exists "v0.4.21"; then ...
git_remote_tag_exists() {
  local tag="$1"
  git ls-remote --exit-code origin "refs/tags/${tag}" >/dev/null 2>&1
}

# Check if a branch exists on the remote. Returns 0 if exists, 1 if not.
# Usage: if git_remote_branch_exists "release/0.4.21"; then ...
git_remote_branch_exists() {
  local branch="$1"
  git ls-remote --exit-code origin "refs/heads/${branch}" >/dev/null 2>&1
}

# Count remote release/* branches. Prints a number (0 if none).
# Usage: count=$(git_count_remote_release_branches)
git_count_remote_release_branches() {
  git branch -r | grep -c '^[[:space:]]*origin/release/' || true
}

# Find the version string of an existing remote release branch.
# Prints the version (e.g. "0.4.21") or empty string if none found.
# Usage: ver=$(git_find_existing_release)
git_find_existing_release() {
  git branch -r | grep '^[[:space:]]*origin/release/' | head -n1 | sed 's|.*origin/release/||' | tr -d '[:space:]'
}

# Push refs atomically to origin.
# Usage: git_atomic_push main develop refs/tags/v0.4.21
git_atomic_push() {
  echo "Pushing changes to remote (atomic: all refs push together or none)" >&2
  git push --atomic origin "$@"
}

# Build the push refs string for a finish operation (release or hotfix).
# Includes branch deletion refspec only if the branch still exists on remote.
# Prints the refs string.
# Usage: refs=$(git_build_finish_refs main develop "refs/tags/v0.4.21" "release/0.4.21")
git_build_finish_refs() {
  local main_branch="$1"
  local dev_branch="$2"
  local tag_ref="$3"
  local source_branch="$4"
  local push_refs="${main_branch} ${dev_branch} ${tag_ref}"
  if git ls-remote --exit-code origin "refs/heads/${source_branch}" >/dev/null 2>&1; then
    push_refs="${push_refs} :${source_branch}"
  else
    echo "WARN: Remote branch ${source_branch} already deleted — skipping deletion refspec" >&2
  fi
  echo "$push_refs"
}
