#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Integration test: hotfix-finish lifecycle
# Tests both the auto-bump path (VERSION == main) and the skip-bump path (VERSION != main).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/../scripts/tomshley-cicd-pipelines-toolbox" && pwd)"

echo "=== test-flow-hotfix-lifecycle ==="

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

# ==========================================================================
# Test 1: hotfix-finish with auto-bump (VERSION matches main)
# ==========================================================================
echo ""
echo "--- hotfix-finish (auto-bump) ---"

REPO_DIR=$(bash "$SCRIPT_DIR/fixtures/setup-test-repo.sh")
echo "Test repo: ${REPO_DIR}"

export TOMSHLEY_CICD_PROJECT_DIR="$REPO_DIR"
export TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX="Test CI"
export TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER="[skip ci]"

cd "$REPO_DIR"

# Create hotfix branch from main (VERSION is 0.4.20, same as main)
git checkout main >/dev/null 2>&1
git checkout -b hotfix/0.4.21 >/dev/null 2>&1
git push origin hotfix/0.4.21 >/dev/null 2>&1

export TOMSHLEY_CICD_CURRENT_BRANCH="hotfix/0.4.21"
bash "$TOOLBOX_DIR/flow/hotfix-finish.sh"

cd "$REPO_DIR"

# Check tag exists
if git rev-parse "refs/tags/v0.4.21" >/dev/null 2>&1; then
  echo "  PASS: tag v0.4.21 exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: tag v0.4.21 does not exist"
  FAIL=$((FAIL + 1))
fi

# Check main has the hotfix merge
git checkout main >/dev/null 2>&1
MAIN_VER=$(cat VERSION | tr -d '[:space:]')
assert_eq "main VERSION is 0.4.21 (auto-bumped)" "0.4.21" "$MAIN_VER"

# Check develop has the hotfix merge
git checkout develop >/dev/null 2>&1
DEV_VER=$(cat VERSION | tr -d '[:space:]')
assert_eq "develop VERSION is 0.4.21 (auto-bumped)" "0.4.21" "$DEV_VER"

# Check hotfix branch is deleted on remote
if git ls-remote --exit-code origin "refs/heads/hotfix/0.4.21" >/dev/null 2>&1; then
  echo "  FAIL: remote hotfix/0.4.21 still exists (should be deleted)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: remote hotfix/0.4.21 deleted"
  PASS=$((PASS + 1))
fi

rm -rf "$(dirname "$REPO_DIR")"

# ==========================================================================
# Test 2: hotfix-finish with skip-bump (VERSION already differs from main)
# ==========================================================================
echo ""
echo "--- hotfix-finish (skip-bump) ---"

REPO_DIR=$(bash "$SCRIPT_DIR/fixtures/setup-test-repo.sh")
echo "Test repo: ${REPO_DIR}"

export TOMSHLEY_CICD_PROJECT_DIR="$REPO_DIR"

cd "$REPO_DIR"

# Create hotfix branch from main, then manually change VERSION
git checkout main >/dev/null 2>&1
git checkout -b hotfix/manual-bump >/dev/null 2>&1
echo "0.4.99" > VERSION
git add VERSION
git commit -m "chore: manual version bump to 0.4.99" >/dev/null 2>&1
git push origin hotfix/manual-bump >/dev/null 2>&1

export TOMSHLEY_CICD_CURRENT_BRANCH="hotfix/manual-bump"
bash "$TOOLBOX_DIR/flow/hotfix-finish.sh"

cd "$REPO_DIR"

# Check tag uses the manual version (no auto-bump)
if git rev-parse "refs/tags/v0.4.99" >/dev/null 2>&1; then
  echo "  PASS: tag v0.4.99 exists (manual version preserved)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: tag v0.4.99 does not exist (manual version not preserved)"
  FAIL=$((FAIL + 1))
fi

# Check main has the manual version
git checkout main >/dev/null 2>&1
MAIN_VER=$(cat VERSION | tr -d '[:space:]')
assert_eq "main VERSION is 0.4.99 (manual, skip-bump)" "0.4.99" "$MAIN_VER"

rm -rf "$(dirname "$REPO_DIR")"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
