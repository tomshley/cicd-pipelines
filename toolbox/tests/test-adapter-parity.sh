#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Test: Verify critical adapter parity for toolbox configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GITLAB_ADAPTER="$PROJECT_ROOT/adapters/gitlab/ci/adapter.yml"
BITBUCKET_ADAPTER="$PROJECT_ROOT/adapters/bitbucket/ci/adapter.yml"

PASS_COUNT=0
FAIL_COUNT=0

assert_grep() {
  local desc="$1"
  local pattern="$2"
  local file="$3"
  if grep -qE "$pattern" "$file"; then
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $desc"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_contains() {
  local desc="$1"
  local haystack="$2"
  local needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $desc"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "=== test-adapter-parity ==="

GITLAB_GIT_PUSH_CONFIG=$(awk '
  /^\.tomshley-cicd-git-push-config:/ { in_block=1 }
  in_block { print }
  in_block && /^#endregion$/ { exit }
' "$GITLAB_ADAPTER")

GITLAB_MIRROR_CONFIG=$(awk '
  /^\.tomshley-cicd-mirror-config:/ { in_block=1 }
  in_block { print }
  in_block && /^#endregion$/ { exit }
' "$GITLAB_ADAPTER")

GITLAB_BOOTSTRAP=$(awk '
  /^\.tomshley-cicd-bootstrap:/ { in_block=1 }
  in_block { print }
  in_block && /^#endregion$/ { exit }
' "$GITLAB_ADAPTER")

for var in \
  TOMSHLEY_CICD_MIRROR_URL \
  TOMSHLEY_CICD_MIRROR_BRANCHES \
  TOMSHLEY_CICD_MIRROR_BRANCH_MAP \
  TOMSHLEY_CICD_MIRROR_TAGS \
  TOMSHLEY_CICD_MIRROR_SSH_KEY \
  TOMSHLEY_CICD_MIRROR_FORCE_PUSH
 do
  assert_grep "GitLab adapter defines ${var}" "${var}" "$GITLAB_ADAPTER"
  assert_grep "Bitbucket adapter defines ${var}" "${var}" "$BITBUCKET_ADAPTER"
 done

assert_grep "GitLab adapter defines toolbox root" 'TOMSHLEY_CICD_TOOLBOX_ROOT' "$GITLAB_ADAPTER"
assert_grep "Bitbucket adapter exports toolbox root" 'export TOMSHLEY_CICD_TOOLBOX_ROOT=' "$BITBUCKET_ADAPTER"
assert_grep "GitLab adapter defines flow image" 'CICD_PIPELINES_FLOW_IMAGE' "$GITLAB_ADAPTER"
assert_grep "Bitbucket adapter has flow image anchor" '&flow-image-name' "$BITBUCKET_ADAPTER"
assert_grep "GitLab adapter defines flow push user" 'TOMSHLEY_CICD_FLOW_PUSH_USER' "$GITLAB_ADAPTER"
assert_grep "Bitbucket adapter exports flow push user" 'export TOMSHLEY_CICD_FLOW_PUSH_USER=' "$BITBUCKET_ADAPTER"
assert_contains "GitLab git push config includes debug before_script" "$GITLAB_GIT_PUSH_CONFIG" '!reference [.tomshley-cicd-debug, before_script]'
assert_contains "GitLab git push config exports build version" "$GITLAB_GIT_PUSH_CONFIG" 'export TOMSHLEY_CICD_BUILD_VERSION=' 
assert_contains "GitLab mirror config includes debug before_script" "$GITLAB_MIRROR_CONFIG" '!reference [.tomshley-cicd-debug, before_script]'
assert_contains "GitLab mirror config exports build version" "$GITLAB_MIRROR_CONFIG" 'export TOMSHLEY_CICD_BUILD_VERSION='
assert_contains "GitLab bootstrap includes debug banner reference" "$GITLAB_BOOTSTRAP" '!reference [.tomshley-cicd-debug, before_script]'
assert_grep "Bitbucket adapter has debug banner" '=== CI/CD Git Flow ===' "$BITBUCKET_ADAPTER"
assert_grep "Bitbucket adapter exports flow type" 'export TOMSHLEY_CICD_FLOW_TYPE=' "$BITBUCKET_ADAPTER"
assert_grep "Bitbucket adapter exports build revision" 'export TOMSHLEY_CICD_BUILD_REVISION=' "$BITBUCKET_ADAPTER"
assert_grep "Bitbucket adapter uses the flow image anchor" 'name: \*flow-image-name' "$BITBUCKET_ADAPTER"
assert_grep "Bitbucket adapter has ensure-tools anchor" '&toolbox-ensure-tools' "$BITBUCKET_ADAPTER"
assert_grep "Bitbucket adapter has core env anchor" '&toolbox-core-env' "$BITBUCKET_ADAPTER"
assert_grep "Bitbucket adapter has mirror env anchor" '&toolbox-mirror-env' "$BITBUCKET_ADAPTER"
assert_grep "Bitbucket adapter has bootstrap anchor" '&toolbox-bootstrap' "$BITBUCKET_ADAPTER"

echo

echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
