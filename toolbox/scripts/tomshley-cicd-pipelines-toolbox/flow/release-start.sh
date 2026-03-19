#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Flow: release-start (develop → release/*)
# Creates a new release branch from develop with a bumped patch version.
#
# Required env vars:
#   TOMSHLEY_CICD_PROJECT_DIR — project root (set by platform script)
# Optional environment variables:
#   TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX — flow message prefix for git commits (default: "Tomshley CI Pipeline")
set -euo pipefail
if [ -n "${BASH_VERSION:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="${TOMSHLEY_CICD_TOOLBOX_ROOT:-/opt/tomshley-cicd-pipelines-toolbox}/flow"
fi
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
if [ "$RELEASE_COUNT" -gt 0 ]; then
  EXISTING=$(git_find_existing_release)
  log_error "Active release branch exists: release/${EXISTING}"
  log_error "Use 'release-continue', 'release-cancel-new', or 'release-start-skip'"
  exit 1
fi

CURRENT_VERSION=$(version_read "$VERSION_FILE")
version_validate "$CURRENT_VERSION"
NEXT_VERSION=$(version_bump_patch "$CURRENT_VERSION")
NEXT_TAG_VERSION=$(version_to_tag "$NEXT_VERSION")

echo "Current version: ${CURRENT_VERSION}"
echo "Next version:    ${NEXT_VERSION}"

if git_tag_exists "$NEXT_TAG_VERSION"; then
  log_fatal "Tag ${NEXT_TAG_VERSION} already exists — aborting"
fi
if git_remote_branch_exists "release/${NEXT_VERSION}"; then
  log_error "release/${NEXT_VERSION} already exists on remote — aborting"
  log_error "Use 'release-continue' to work on it, 'release-cancel-new' to replace it,"
  log_error "or 'release-start-skip' to skip to the next version"
  exit 1
fi
git checkout -B "release/${NEXT_VERSION}"

echo "${NEXT_VERSION}" > "$VERSION_FILE"
git add "$VERSION_FILE"
git commit -m "chore: bump version to ${NEXT_VERSION}"
# Recheck both tag and branch immediately before push to prevent TOCTOU race
if git_tag_exists "$NEXT_TAG_VERSION"; then
  log_fatal "Tag ${NEXT_TAG_VERSION} was created during release start — aborting"
fi
if git_remote_branch_exists "release/${NEXT_VERSION}"; then
  log_fatal "release/${NEXT_VERSION} was created during release start — aborting"
fi
git push --set-upstream origin "release/${NEXT_VERSION}"
