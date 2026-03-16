#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Test: Verify adapter YAML hardcoded versions match PINNED_PIPELINE_VERSIONS

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

echo "=== test-pinned-versions ==="

# Source PINNED_PIPELINE_VERSIONS
if [ ! -f "$PROJECT_ROOT/PINNED_PIPELINE_VERSIONS" ]; then
  echo "FAIL: PINNED_PIPELINE_VERSIONS not found"
  exit 1
fi

set -a
source "$PROJECT_ROOT/PINNED_PIPELINE_VERSIONS"
set +a

# Check .adapter.yml (git-push-config section)
# NOTE: grep patterns assume values are indented (inside a variables: block).
# If the YAML structure changes, these extractions may silently break.
ADAPTER="$PROJECT_ROOT/adapters/gitlab/ci/adapter.yml"
if [ -f "$ADAPTER" ]; then
  YAML_REGISTRY=$(grep -E '^\s+CICD_PIPELINES_REGISTRY:' "$ADAPTER" | head -1 | awk '{print $2}' | tr -d "\"'")
  YAML_TAG=$(grep -E '^\s+CICD_PIPELINES_RUNNER_TAG:' "$ADAPTER" | head -1 | awk '{print $2}' | tr -d "\"'")
  
  assert_equal ".adapter.yml CICD_PIPELINES_REGISTRY (git-push-config)" "$CICD_PIPELINES_REGISTRY" "$YAML_REGISTRY"
  assert_equal ".adapter.yml CICD_PIPELINES_RUNNER_TAG (git-push-config)" "$CICD_PIPELINES_RUNNER_TAG" "$YAML_TAG"

  # mirror-config inherits these via extends: .tomshley-cicd-git-push-config
  # so only one definition needs to be checked
else
  echo "  FAIL: .adapter.yml not found"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Check .gitlab-ci.yml for BASE_CONTAINERS_UPSTREAM_TAG
GITLAB_CI="$PROJECT_ROOT/.gitlab-ci.yml"
if [ -f "$GITLAB_CI" ]; then
  YAML_BASE_TAG=$(grep -E '^\s+BASE_CONTAINERS_UPSTREAM_TAG:' "$GITLAB_CI" | head -1 | awk '{print $2}' | tr -d "\"'")
  
  assert_equal ".gitlab-ci.yml BASE_CONTAINERS_UPSTREAM_TAG" "$BASE_CONTAINERS_UPSTREAM_TAG" "$YAML_BASE_TAG"
else
  echo "  FAIL: .gitlab-ci.yml not found"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
