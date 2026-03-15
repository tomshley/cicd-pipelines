#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Flow: release-continue (checkout existing release branch, merge develop into it)
#
# Required env vars:
#   TOMSHLEY_CICD_PROJECT_DIR — project root (set by platform script)
# Optional environment variables:
#   TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX — flow message prefix for git commits (default: "Tomshley CI Pipeline")
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/version.sh"
source "$TOOLBOX_DIR/lib/git.sh"

: "${TOMSHLEY_CICD_PROJECT_DIR:?required}"
: "${TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX:=Tomshley CI Pipeline}"

cd "$TOMSHLEY_CICD_PROJECT_DIR"

git_fetch_tags
git_checkout_pull_rebase develop

RELEASE_COUNT=$(git_count_remote_release_branches)
if [ "$RELEASE_COUNT" -gt 1 ]; then
  log_error "Multiple release branches detected — manual cleanup required"
  git branch -r | grep '^[[:space:]]*origin/release/'
  exit 1
fi
EXISTING_RELEASE=$(git_find_existing_release)
if [ -z "$EXISTING_RELEASE" ]; then
  log_error "No active release branch found"
  log_error "Use 'release-start' to create a new release"
  exit 1
fi

echo "Found existing release: release/${EXISTING_RELEASE}"
echo "Checking out existing release: release/${EXISTING_RELEASE}"
git checkout -B "release/${EXISTING_RELEASE}" "origin/release/${EXISTING_RELEASE}"
echo "[ok] On release/${EXISTING_RELEASE}"
echo "Merging develop into release/${EXISTING_RELEASE}..."
export GIT_MERGE_AUTOEDIT=no
git merge develop --no-ff --no-edit -m "chore: merge develop into release/${EXISTING_RELEASE}"
unset GIT_MERGE_AUTOEDIT
VERSION_FILE="${TOMSHLEY_CICD_PROJECT_DIR}/VERSION"
MERGED_VERSION=$(version_read "$VERSION_FILE")
version_validate "$MERGED_VERSION"
# Recheck remote branch existence immediately before push to prevent TOCTOU race
if ! git_remote_branch_exists "release/${EXISTING_RELEASE}"; then
  log_fatal "Remote branch release/${EXISTING_RELEASE} was deleted during merge — aborting"
fi
git push origin "release/${EXISTING_RELEASE}"
echo "[ok] Merged develop and pushed release/${EXISTING_RELEASE}"
