#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Flow: release-finish (release/* → main + develop, tag, cleanup)
#
# Required env vars:
#   TOMSHLEY_CICD_PROJECT_DIR      — project root (set by platform script)
#   TOMSHLEY_CICD_CURRENT_BRANCH   — the release/* branch name (set by platform script)
# Optional env vars:
#   TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX  — commit message prefix
#   TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER — skip-ci marker for develop merges
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/version.sh"
source "$TOOLBOX_DIR/lib/git.sh"

: "${TOMSHLEY_CICD_PROJECT_DIR:?required}"
: "${TOMSHLEY_CICD_CURRENT_BRANCH:?required}"
: "${TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX:=Tomshley CI Pipeline}"
: "${TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER:=[skip ci]}"

cd "$TOMSHLEY_CICD_PROJECT_DIR"

VERSION_FILE="${TOMSHLEY_CICD_PROJECT_DIR}/VERSION"
RELEASE_BRANCH="${TOMSHLEY_CICD_CURRENT_BRANCH}"

if ! echo "$RELEASE_BRANCH" | grep -qE '^release/.+$'; then
  log_fatal "TOMSHLEY_CICD_CURRENT_BRANCH must match 'release/*' pattern, got: ${RELEASE_BRANCH}"
fi

git_fetch_tags
git_checkout_pull_ff "${RELEASE_BRANCH}"

RELEASE_VERSION=$(version_read "$VERSION_FILE")
version_validate "$RELEASE_VERSION"
RELEASE_TAG_VERSION=$(version_to_tag "$RELEASE_VERSION")
FINISH_MESSAGE="${TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX} Release Version ${RELEASE_VERSION}"

echo "Finishing release: ${RELEASE_BRANCH}"
echo "Release version:  ${RELEASE_VERSION}"

if git_tag_exists "$RELEASE_TAG_VERSION"; then
  log_fatal "Tag ${RELEASE_TAG_VERSION} already exists — aborting"
fi

export GIT_MERGE_AUTOEDIT=no
git checkout main
git pull origin main --ff-only --prune
git merge --no-ff --no-edit "${RELEASE_BRANCH}" -m "${FINISH_MESSAGE} | main"
git tag -a "${RELEASE_TAG_VERSION}" -m "${FINISH_MESSAGE}"
git checkout develop
git pull origin develop --ff-only --prune
git merge --no-ff --no-edit "${RELEASE_BRANCH}" -m "${FINISH_MESSAGE} | develop | ${TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER}"
git branch -D "${RELEASE_BRANCH}"
# Recheck remote tag immediately before push to prevent TOCTOU race
# (local tag already exists from git tag -a above — check the remote)
if git_remote_tag_exists "$RELEASE_TAG_VERSION"; then
  log_fatal "Tag ${RELEASE_TAG_VERSION} was created on remote during release finish — aborting"
fi
PUSH_REFS=$(git_build_finish_refs main develop "refs/tags/${RELEASE_TAG_VERSION}" "${RELEASE_BRANCH}")
git_atomic_push ${PUSH_REFS}
unset GIT_MERGE_AUTOEDIT
