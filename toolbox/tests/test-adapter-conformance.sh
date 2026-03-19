#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Test: Verify all adapters invoke the same set of toolbox scripts

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0

assert_equal() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $desc"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "=== test-adapter-conformance ==="

GITLAB_ADAPTER="$PROJECT_ROOT/adapters/gitlab/ci/adapter.yml"
BITBUCKET_ADAPTER="$PROJECT_ROOT/adapters/bitbucket/ci/adapter.yml"

# Extract toolbox script paths from each adapter (sorted, unique, one per line)
GL_SCRIPTS=$(grep -oE '\$\{TOMSHLEY_CICD_TOOLBOX_ROOT\}/(flow|mirror)/[a-z-]+\.sh' "$GITLAB_ADAPTER" | sed 's|^${TOMSHLEY_CICD_TOOLBOX_ROOT}/||' | sort -u)
BB_SCRIPTS=$(grep -oE '\$\{TOMSHLEY_CICD_TOOLBOX_ROOT\}/(flow|mirror)/[a-z-]+\.sh' "$BITBUCKET_ADAPTER" | sed 's|^${TOMSHLEY_CICD_TOOLBOX_ROOT}/||' | sort -u)

assert_equal "Toolbox script sets match" "$GL_SCRIPTS" "$BB_SCRIPTS"

# Count scripts as sanity check (should be 7)
GL_COUNT=$(echo "$GL_SCRIPTS" | wc -l | tr -d ' ')
assert_equal "GitLab adapter invokes 7 toolbox scripts" "7" "$GL_COUNT"

BB_COUNT=$(echo "$BB_SCRIPTS" | wc -l | tr -d ' ')
assert_equal "Bitbucket adapter invokes 7 toolbox scripts" "7" "$BB_COUNT"

# Check both adapters source toolbox-entry.sh
GL_ENTRY=$(grep -c 'toolbox-entry.sh' "$GITLAB_ADAPTER" || echo "0")
BB_ENTRY=$(grep -c 'toolbox-entry.sh' "$BITBUCKET_ADAPTER" || echo "0")

if [ "$GL_ENTRY" -gt 0 ]; then
  echo "  PASS: GitLab adapter sources toolbox-entry.sh"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: GitLab adapter does not source toolbox-entry.sh"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if [ "$BB_ENTRY" -gt 0 ]; then
  echo "  PASS: Bitbucket adapter sources toolbox-entry.sh"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: Bitbucket adapter does not source toolbox-entry.sh"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

