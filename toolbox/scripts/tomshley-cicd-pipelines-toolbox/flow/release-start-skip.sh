#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Flow: release-start-skip (skip existing release, bump to next+1 version)
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

VERSION_FILE="${TOMSHLEY_CICD_PROJECT_DIR}/VERSION"

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
  log_error "No active release branch exists to skip"
  log_error "Use 'release-start' for normal release flow"
  exit 1
fi
echo "Found existing release: release/${EXISTING_RELEASE}"
echo "Creating new release that skips this version"

CURRENT_VERSION=$(version_read "$VERSION_FILE")
version_validate "$CURRENT_VERSION"
# Increment twice to skip the existing release version
NEXT_VERSION=$(version_bump_patch_skip "$CURRENT_VERSION")
NEXT_TAG_VERSION=$(version_to_tag "$NEXT_VERSION")

echo "Current version: ${CURRENT_VERSION}"
echo "Skipping to:     ${NEXT_VERSION}"

if git_tag_exists "$NEXT_TAG_VERSION"; then
  log_fatal "Tag ${NEXT_TAG_VERSION} already exists — aborting"
fi
if git_remote_branch_exists "release/${NEXT_VERSION}"; then
  log_fatal "release/${NEXT_VERSION} already exists on remote — aborting"
fi

# Delete the old release branch before creating the new one
echo "Deleting old release: release/${EXISTING_RELEASE}"
if git_remote_branch_exists "release/${EXISTING_RELEASE}"; then
  if git push origin --delete "release/${EXISTING_RELEASE}" 2>/dev/null; then
    echo "[ok] Deleted remote branch: release/${EXISTING_RELEASE}"
    git fetch --prune 2>/dev/null || true
  else
    log_fatal "Failed to delete release/${EXISTING_RELEASE} — check push token permissions"
  fi
else
  log_warn "release/${EXISTING_RELEASE} already deleted — proceeding with new release"
fi

git checkout -B "release/${NEXT_VERSION}"

echo "${NEXT_VERSION}" > "$VERSION_FILE"
git add "$VERSION_FILE"
git commit -m "chore: bump version to ${NEXT_VERSION} (skip release)"
# Recheck tag and branch existence immediately before push to prevent TOCTOU race
if git_tag_exists "$NEXT_TAG_VERSION"; then
  log_fatal "Tag ${NEXT_TAG_VERSION} was created during skip operation — aborting"
fi
if git_remote_branch_exists "release/${NEXT_VERSION}"; then
  log_fatal "release/${NEXT_VERSION} was created during skip operation — aborting"
fi
git push --set-upstream origin "release/${NEXT_VERSION}"
echo "[ok] Created skip release: release/${NEXT_VERSION}"
