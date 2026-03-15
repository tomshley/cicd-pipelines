#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Integration test: release-start → release-continue → release-finish lifecycle
# Creates a release, merges develop into it, then finishes the release.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/../scripts/tomshley-cicd-pipelines-toolbox" && pwd)"

echo "=== test-flow-release-continue ==="

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
BRANCH=$(git rev-parse --abbrev-ref HEAD)
assert_eq "on release/0.4.21 after start" "release/0.4.21" "$BRANCH"

# --- Step 2: Add a commit to develop (simulates ongoing work) ---
echo ""
echo "--- add commit to develop ---"
cd "$REPO_DIR"
git checkout develop >/dev/null 2>&1
echo "new-feature" > FEATURE.txt
git add FEATURE.txt
git commit -m "feat: add feature" >/dev/null 2>&1
git push origin develop >/dev/null 2>&1

# --- Step 3: Run release-continue ---
echo ""
echo "--- release-continue ---"
bash "$TOOLBOX_DIR/flow/release-continue.sh"

cd "$REPO_DIR"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
assert_eq "on release/0.4.21 after continue" "release/0.4.21" "$BRANCH"

# Check that the feature file from develop is now on the release branch
if [ -f FEATURE.txt ]; then
  echo "  PASS: FEATURE.txt merged from develop into release"
  PASS=$((PASS + 1))
else
  echo "  FAIL: FEATURE.txt not found on release branch after continue"
  FAIL=$((FAIL + 1))
fi

VERSION_CONTENT=$(cat VERSION | tr -d '[:space:]')
assert_eq "VERSION still 0.4.21 after continue" "0.4.21" "$VERSION_CONTENT"

# Check remote branch was pushed
if git ls-remote --exit-code origin "refs/heads/release/0.4.21" >/dev/null 2>&1; then
  echo "  PASS: remote release/0.4.21 still exists after continue"
  PASS=$((PASS + 1))
else
  echo "  FAIL: remote release/0.4.21 missing after continue"
  FAIL=$((FAIL + 1))
fi

# --- Step 4: Finish the release ---
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

# Check FEATURE.txt made it to main via the release
git checkout main >/dev/null 2>&1
if [ -f FEATURE.txt ]; then
  echo "  PASS: FEATURE.txt on main after finish"
  PASS=$((PASS + 1))
else
  echo "  FAIL: FEATURE.txt missing on main after finish"
  FAIL=$((FAIL + 1))
fi

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
