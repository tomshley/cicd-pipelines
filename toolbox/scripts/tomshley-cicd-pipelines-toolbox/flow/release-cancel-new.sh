#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Flow: release-cancel-new (delete existing release, create fresh from develop)
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
source "$TOOLBOX_DIR/lib/flow.sh"

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
  log_error "No active release branch found to cancel"
  log_error "Use 'release-start' to create a new release"
  exit 1
fi

# Validate version consistency before deletion
CURRENT_VERSION=$(version_read "$VERSION_FILE")
version_validate "$CURRENT_VERSION"
NEXT_VERSION=$(version_bump_patch "$CURRENT_VERSION")
NEXT_TAG_VERSION=$(version_to_tag "$NEXT_VERSION")
NEXT_VERSION_NO_PREFIX=$(version_strip "$NEXT_VERSION")
EXISTING_VERSION_NO_PREFIX=$(version_strip "$EXISTING_RELEASE")

echo "Existing release: release/${EXISTING_RELEASE}"
echo "Current version:  ${CURRENT_VERSION}"
echo "Next version:     ${NEXT_VERSION}"

if [ "${NEXT_VERSION_NO_PREFIX}" != "${EXISTING_VERSION_NO_PREFIX}" ]; then
  log_warn "Version mismatch detected"
  log_warn "      Existing release is ${EXISTING_RELEASE}, but develop VERSION suggests ${NEXT_VERSION}"
  log_warn "      Proceeding with ${NEXT_VERSION} (develop-based)"
fi

# Validate tag and new branch don't exist BEFORE deleting anything
if git_tag_exists "$NEXT_TAG_VERSION"; then
  log_fatal "Tag ${NEXT_TAG_VERSION} already exists — aborting"
fi
# Skip remote branch check when NEXT == EXISTING (we are about to delete it)
if [ "${NEXT_VERSION_NO_PREFIX}" != "${EXISTING_VERSION_NO_PREFIX}" ] && git_remote_branch_exists "release/${NEXT_VERSION}"; then
  log_fatal "Branch release/${NEXT_VERSION} already exists — aborting"
fi

echo "Canceling and replacing release: release/${EXISTING_RELEASE}"
if git_remote_branch_exists "release/${EXISTING_RELEASE}"; then
  if git push origin --delete "release/${EXISTING_RELEASE}" 2>/dev/null; then
    echo "[ok] Deleted remote branch: release/${EXISTING_RELEASE}"
    git fetch --prune 2>/dev/null || true
  else
    log_fatal "Failed to delete release/${EXISTING_RELEASE} — check CI push permissions in your platform settings"
  fi
else
  log_warn "release/${EXISTING_RELEASE} already deleted — proceeding with new release"
fi
git checkout -B "release/${NEXT_VERSION}"

echo "${NEXT_VERSION}" > "$VERSION_FILE"
git add "$VERSION_FILE"
git commit -m "chore: bump version to ${NEXT_VERSION}"
# Recheck tag and branch existence immediately before push to prevent TOCTOU race
if git_tag_exists "$NEXT_TAG_VERSION"; then
  log_fatal "Tag ${NEXT_TAG_VERSION} was created during branch replacement — aborting"
fi
if git_remote_branch_exists "release/${NEXT_VERSION}"; then
  log_fatal "release/${NEXT_VERSION} was created during branch replacement — aborting"
fi
git push --set-upstream origin "release/${NEXT_VERSION}"
echo "[ok] Created fresh release: release/${NEXT_VERSION}"
