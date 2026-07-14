#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Integration test: TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_PATTERN derivation
# and optional (empty) TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/../scripts/tomshley-cicd-pipelines-toolbox" && pwd)"

echo "=== test-flow-prefix-derive ==="

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

# --- Unit: explicit prefix wins over pattern ---
echo ""
echo "--- explicit prefix wins ---"
EXPLICIT_RESULT=$(
  source "$TOOLBOX_DIR/lib/log.sh"
  source "$TOOLBOX_DIR/lib/flow.sh"
  TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX="EXPLICIT-1:"
  TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_PATTERN='[A-Z]{2,}-[0-9]+'
  flow_resolve_message_prefix >/dev/null
  printf '%s' "$TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX"
)
assert_eq "explicit prefix untouched" "EXPLICIT-1:" "$EXPLICIT_RESULT"

# --- Integration: derive from history, skip-ci disabled ---
# Create test repo
REPO_DIR=$(bash "$SCRIPT_DIR/fixtures/setup-test-repo.sh")
echo "Test repo: ${REPO_DIR}"

# Seed a keyed commit on develop (the key the pattern should pick up)
cd "$REPO_DIR"
git checkout develop >/dev/null 2>&1
echo "seed" > seed.txt
git add seed.txt
git commit -q -m "XY-42: seed feature work"
git push -q origin develop

# Canonical env: no explicit prefix, pattern set, skip-ci marker explicitly empty
export TOMSHLEY_CICD_PROJECT_DIR="$REPO_DIR"
unset TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX || true
export TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_PATTERN='[A-Z]{2,}-[0-9]+'
export TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER=""

echo ""
echo "--- release-start (derived prefix) ---"
bash "$TOOLBOX_DIR/flow/release-start.sh"

cd "$REPO_DIR"
BUMP_SUBJECT=$(git log -1 --format=%s)
assert_eq "bump commit carries derived key" "XY-42 chore: bump version to 0.4.21" "$BUMP_SUBJECT"

echo ""
echo "--- release-finish (derived prefix, no skip-ci) ---"
export TOMSHLEY_CICD_CURRENT_BRANCH="release/0.4.21"
unset TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX || true
bash "$TOOLBOX_DIR/flow/release-finish.sh"

cd "$REPO_DIR"
git checkout main >/dev/null 2>&1
MAIN_SUBJECT=$(git log -1 --format=%s)
assert_eq "main merge message" "XY-42 Release Version 0.4.21 | main" "$MAIN_SUBJECT"

TAG_MESSAGE=$(git tag -l --format='%(contents:subject)' v0.4.21)
assert_eq "tag message carries derived key" "XY-42 Release Version 0.4.21" "$TAG_MESSAGE"

git checkout develop >/dev/null 2>&1
DEV_SUBJECT=$(git log -1 --format=%s)
assert_eq "develop merge message (skip-ci disabled, no trailing separator)" "XY-42 Release Version 0.4.21 | develop" "$DEV_SUBJECT"

# Cleanup
rm -rf "$(dirname "$REPO_DIR")"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
