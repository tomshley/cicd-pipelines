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

# Job-facing toolbox categories: every script here is an adapter entry point.
# lib/, platform/, docker/, and secrets/ are sourced or invoked by scripts and
# platform-specific fragments, not by every adapter.
CATEGORIES='flow|mirror|publish|verify|build|retention'

# Extract toolbox script paths from each adapter (sorted, unique, one per line)
GL_SCRIPTS=$(grep -oE "\\\$\\{TOMSHLEY_CICD_TOOLBOX_ROOT\\}/(${CATEGORIES})/[a-z-]+\\.sh" "$GITLAB_ADAPTER" | sed 's|^${TOMSHLEY_CICD_TOOLBOX_ROOT}/||' | sort -u)
BB_SCRIPTS=$(grep -oE "\\\$\\{TOMSHLEY_CICD_TOOLBOX_ROOT\\}/(${CATEGORIES})/[a-z-]+\\.sh" "$BITBUCKET_ADAPTER" | sed 's|^${TOMSHLEY_CICD_TOOLBOX_ROOT}/||' | sort -u)

assert_equal "Toolbox script sets match" "$GL_SCRIPTS" "$BB_SCRIPTS"

# Source-of-truth: every job-facing script in the toolbox MUST be invoked by
# every adapter. This avoids drift between adapters and keeps the assertion
# stable when scripts are added or removed.
TOOLBOX_SCRIPTS_DIR="$PROJECT_ROOT/toolbox/scripts/tomshley-cicd-pipelines-toolbox"
EXPECTED_SCRIPTS=$(cd "$TOOLBOX_SCRIPTS_DIR" && find flow mirror publish verify build retention -maxdepth 1 -type f -name '*.sh' | sort -u)

assert_equal "GitLab adapter invokes every job-facing toolbox script" "$EXPECTED_SCRIPTS" "$GL_SCRIPTS"
assert_equal "Bitbucket adapter invokes every job-facing toolbox script" "$EXPECTED_SCRIPTS" "$BB_SCRIPTS"

# Adapters map platform refs into the artifact policy interface the same way.
for var in TOMSHLEY_CICD_REF_SLUG TOMSHLEY_CICD_COMMIT_SHA TOMSHLEY_CICD_TAG; do
  assert_equal "GitLab adapter exports ${var}" "yes" "$(grep -qE "export ${var}=" "$GITLAB_ADAPTER" && echo yes || echo no)"
  assert_equal "Bitbucket adapter exports ${var}" "yes" "$(grep -qE "export ${var}=" "$BITBUCKET_ADAPTER" && echo yes || echo no)"
done

# Only platform/ scripts may be sourced into the job shell; everything else is
# executed so recipe shell options never leak into the adapter's before_script.
for adapter in "$GITLAB_ADAPTER" "$BITBUCKET_ADAPTER"; do
  SOURCED=$(grep -oE "source \"?\\\$\\{?TOMSHLEY_CICD_TOOLBOX_ROOT\\}?/[a-z]+/" "$adapter" | grep -vE '/platform/$' || true)
  assert_equal "$(basename "$(dirname "$(dirname "$adapter")")") adapter sources only platform/ scripts" "" "$SOURCED"
done

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

