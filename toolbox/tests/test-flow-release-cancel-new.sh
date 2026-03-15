#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Integration test: release-start → release-cancel-new → release-finish lifecycle
# Creates a release, cancels it, creates a fresh one from develop, then finishes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/../scripts/tomshley-cicd-pipelines-toolbox" && pwd)"

echo "=== test-flow-release-cancel-new ==="

REPO_DIR=$(bash "$SCRIPT_DIR/fixtures/setup-test-repo.sh")
echo "Test repo: ${REPO_DIR}"

export TOMSHLEY_CICD_PROJECT_DIR="$REPO_DIR"
export TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX="Test CI"
export TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER="[skip ci]"

PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: ${label}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${label} — expected '${expected}', got '${actual}'"
    FAIL=$((FAIL + 1))
  fi
}

# --- Step 1: Create a release branch via release-start ---
echo ""
echo "--- release-start (setup) ---"
bash "$TOOLBOX_DIR/flow/release-start.sh"

cd "$REPO_DIR"
assert_eq "on release/0.4.21 after start" "release/0.4.21" "$(git rev-parse --abbrev-ref HEAD)"

# Verify remote branch exists before cancel
if git ls-remote --exit-code origin "refs/heads/release/0.4.21" >/dev/null 2>&1; then
  echo "  PASS: remote release/0.4.21 exists (pre-cancel)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: remote release/0.4.21 does not exist (pre-cancel)"
  FAIL=$((FAIL + 1))
fi

# --- Step 2: Cancel and create new release ---
echo ""
echo "--- release-cancel-new ---"
# Switch back to develop first (release-cancel-new starts from develop)
cd "$REPO_DIR"
git checkout develop >/dev/null 2>&1
bash "$TOOLBOX_DIR/flow/release-cancel-new.sh"

cd "$REPO_DIR"

# When NEXT == EXISTING (both 0.4.21), the script deletes and recreates the
# same branch name from develop. Verify the fresh branch exists.
BRANCH=$(git rev-parse --abbrev-ref HEAD)
assert_eq "on release/0.4.21 after cancel-new" "release/0.4.21" "$BRANCH"

VERSION_CONTENT=$(cat VERSION | tr -d '[:space:]')
assert_eq "VERSION is 0.4.21 after cancel-new" "0.4.21" "$VERSION_CONTENT"

if git ls-remote --exit-code origin "refs/heads/release/0.4.21" >/dev/null 2>&1; then
  echo "  PASS: remote release/0.4.21 exists (freshly recreated)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: remote release/0.4.21 missing after cancel-new"
  FAIL=$((FAIL + 1))
fi

# --- Step 3: Finish the freshly created release ---
echo ""
echo "--- release-finish ---"
export TOMSHLEY_CICD_CURRENT_BRANCH="release/0.4.21"
bash "$TOOLBOX_DIR/flow/release-finish.sh"

cd "$REPO_DIR"

if git rev-parse "refs/tags/v0.4.21" >/dev/null 2>&1; then
  echo "  PASS: tag v0.4.21 exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: tag v0.4.21 does not exist"
  FAIL=$((FAIL + 1))
fi

git checkout main >/dev/null 2>&1
MAIN_VER=$(cat VERSION | tr -d '[:space:]')
assert_eq "main VERSION is 0.4.21" "0.4.21" "$MAIN_VER"

git checkout develop >/dev/null 2>&1
DEV_VER=$(cat VERSION | tr -d '[:space:]')
assert_eq "develop VERSION is 0.4.21" "0.4.21" "$DEV_VER"

if git ls-remote --exit-code origin "refs/heads/release/0.4.21" >/dev/null 2>&1; then
  echo "  FAIL: remote release/0.4.21 still exists (should be deleted)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: remote release/0.4.21 deleted after finish"
  PASS=$((PASS + 1))
fi

# Cleanup
rm -rf "$(dirname "$REPO_DIR")"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
