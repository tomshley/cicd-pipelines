#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Flow: hotfix-finish (hotfix/* → main + develop, tag, cleanup)
# Critical: compares VERSION to origin/main:VERSION — skips bump if already different.
#
# Required env vars:
#   TOMSHLEY_CICD_PROJECT_DIR      — project root (set by platform script)
#   TOMSHLEY_CICD_CURRENT_BRANCH   — the hotfix/* branch name (set by platform script)
# Optional env vars:
#   TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX  — commit message prefix
#   TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER — skip-ci marker for develop merges
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
: "${TOMSHLEY_CICD_CURRENT_BRANCH:?required}"
: "${TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX:=Tomshley CI Pipeline}"
: "${TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER:=[skip ci]}"

cd "$TOMSHLEY_CICD_PROJECT_DIR"

VERSION_FILE="${TOMSHLEY_CICD_PROJECT_DIR}/VERSION"
HOTFIX_BRANCH="${TOMSHLEY_CICD_CURRENT_BRANCH}"

if ! echo "$HOTFIX_BRANCH" | grep -qE '^hotfix/.+$'; then
  log_fatal "TOMSHLEY_CICD_CURRENT_BRANCH must match 'hotfix/*' pattern, got: ${HOTFIX_BRANCH}"
fi

# Step 1: Bump version on hotfix branch
git_fetch_tags
git_checkout_pull_ff "${HOTFIX_BRANCH}"

CURRENT_VERSION=$(version_read "$VERSION_FILE")
version_validate "$CURRENT_VERSION"

# Compare hotfix VERSION to main — skip bump if already different (manual bump)
MAIN_VERSION=$(git show origin/main:VERSION 2>/dev/null | tr -d '[:space:]' || echo "")
if [ -n "$MAIN_VERSION" ] && [ "$CURRENT_VERSION" != "$MAIN_VERSION" ]; then
  NEXT_VERSION="$CURRENT_VERSION"
  echo "VERSION already differs from main (${MAIN_VERSION}) — using ${NEXT_VERSION} as-is"
else
  NEXT_VERSION=$(version_bump_patch "$CURRENT_VERSION")

  echo "${NEXT_VERSION}" > "$VERSION_FILE"
  git add "$VERSION_FILE"
  git commit -m "chore: bump version to ${NEXT_VERSION}"
fi
HOTFIX_TAG_VERSION=$(version_to_tag "$NEXT_VERSION")
FINISH_MESSAGE="${TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX} Hotfix Version ${NEXT_VERSION}"

echo "Finishing hotfix: ${HOTFIX_BRANCH}"
echo "Next version:    ${NEXT_VERSION}"

# Step 2: Merge to main and develop, tag, cleanup
if git_tag_exists "$HOTFIX_TAG_VERSION"; then
  log_fatal "Tag ${HOTFIX_TAG_VERSION} already exists — aborting"
fi

export GIT_MERGE_AUTOEDIT=no
git checkout main
git pull origin main --ff-only --prune
git merge --no-ff --no-edit "${HOTFIX_BRANCH}" -m "${FINISH_MESSAGE} | main"
git tag -a "${HOTFIX_TAG_VERSION}" -m "${FINISH_MESSAGE}"
git checkout develop
git pull origin develop --ff-only --prune
git merge --no-ff --no-edit "${HOTFIX_BRANCH}" -m "${FINISH_MESSAGE} | develop | ${TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER}"
git branch -D "${HOTFIX_BRANCH}"
# Recheck remote tag immediately before push to prevent TOCTOU race
# (local tag already exists from git tag -a above — check the remote)
if git_remote_tag_exists "$HOTFIX_TAG_VERSION"; then
  log_fatal "Tag ${HOTFIX_TAG_VERSION} was created on remote during hotfix finish — aborting"
fi
PUSH_REFS=$(git_build_finish_refs main develop "refs/tags/${HOTFIX_TAG_VERSION}" "${HOTFIX_BRANCH}")
git_atomic_push ${PUSH_REFS}
unset GIT_MERGE_AUTOEDIT
