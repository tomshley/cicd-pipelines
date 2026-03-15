#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Integration test: release-start → release-finish lifecycle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/../scripts/tomshley-cicd-pipelines-toolbox" && pwd)"

echo "=== test-flow-release-lifecycle ==="

# Create test repo
REPO_DIR=$(bash "$SCRIPT_DIR/fixtures/setup-test-repo.sh")
echo "Test repo: ${REPO_DIR}"

# Set canonical env vars (normally done by platform script)
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

# --- Test release-start ---
echo ""
echo "--- release-start ---"
bash "$TOOLBOX_DIR/flow/release-start.sh"

cd "$REPO_DIR"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
assert_eq "on release/0.4.21 branch" "release/0.4.21" "$BRANCH"

VERSION_CONTENT=$(cat VERSION | tr -d '[:space:]')
assert_eq "VERSION is 0.4.21" "0.4.21" "$VERSION_CONTENT"

# Check remote branch exists
if git ls-remote --exit-code origin "refs/heads/release/0.4.21" >/dev/null 2>&1; then
  echo "  PASS: remote release/0.4.21 exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: remote release/0.4.21 does not exist"
  FAIL=$((FAIL + 1))
fi

# --- Test release-finish ---
echo ""
echo "--- release-finish ---"
export TOMSHLEY_CICD_CURRENT_BRANCH="release/0.4.21"
bash "$TOOLBOX_DIR/flow/release-finish.sh"

cd "$REPO_DIR"

# Check tag exists
if git rev-parse "refs/tags/v0.4.21" >/dev/null 2>&1; then
  echo "  PASS: tag v0.4.21 exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: tag v0.4.21 does not exist"
  FAIL=$((FAIL + 1))
fi

# Check main has the release merge
git checkout main >/dev/null 2>&1
MAIN_VER=$(cat VERSION | tr -d '[:space:]')
assert_eq "main VERSION is 0.4.21" "0.4.21" "$MAIN_VER"

# Check develop has the release merge
git checkout develop >/dev/null 2>&1
DEV_VER=$(cat VERSION | tr -d '[:space:]')
assert_eq "develop VERSION is 0.4.21" "0.4.21" "$DEV_VER"

# Check release branch is deleted on remote
if git ls-remote --exit-code origin "refs/heads/release/0.4.21" >/dev/null 2>&1; then
  echo "  FAIL: remote release/0.4.21 still exists (should be deleted)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: remote release/0.4.21 deleted"
  PASS=$((PASS + 1))
fi

# Cleanup
rm -rf "$(dirname "$REPO_DIR")"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
