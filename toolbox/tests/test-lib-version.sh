#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Unit tests for lib/version.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/../scripts/tomshley-cicd-pipelines-toolbox" && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/version.sh"

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

assert_fatal() {
  local label="$1"
  shift
  if ("$@") >/dev/null 2>&1; then
    echo "  FAIL: ${label} — expected fatal, but succeeded"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: ${label}"
    PASS=$((PASS + 1))
  fi
}

echo "=== test-lib-version ==="

# version_read
TMP=$(mktemp -d)
echo "0.4.20" > "$TMP/VERSION"
assert_eq "version_read valid" "0.4.20" "$(version_read "$TMP/VERSION")"
echo "  v1.2.3  " > "$TMP/VERSION"
assert_eq "version_read strips whitespace" "v1.2.3" "$(version_read "$TMP/VERSION")"
assert_fatal "version_read missing file" version_read "$TMP/NONEXISTENT"
echo "" > "$TMP/VERSION"
assert_fatal "version_read empty file" version_read "$TMP/VERSION"
rm -rf "$TMP"

# version_validate
version_validate "0.4.20"    && echo "  PASS: version_validate 0.4.20" && PASS=$((PASS + 1))
version_validate "v1.2.3"    && echo "  PASS: version_validate v1.2.3" && PASS=$((PASS + 1))
assert_fatal "version_validate invalid 1.0 (two-segment)" version_validate "1.0"
assert_fatal "version_validate invalid abc" version_validate "abc"
assert_fatal "version_validate invalid 1.2.3-beta" version_validate "1.2.3-beta"
assert_fatal "version_validate invalid bare number 1" version_validate "1"

# version_prefix
assert_eq "version_prefix v1.2.3" "v" "$(version_prefix "v1.2.3")"
assert_eq "version_prefix 0.4.20" "" "$(version_prefix "0.4.20")"

# version_strip
assert_eq "version_strip v1.2.3" "1.2.3" "$(version_strip "v1.2.3")"
assert_eq "version_strip 0.4.20" "0.4.20" "$(version_strip "0.4.20")"

# version_bump_patch
assert_eq "version_bump_patch 0.4.20" "0.4.21" "$(version_bump_patch "0.4.20")"
assert_eq "version_bump_patch v1.2.3" "v1.2.4" "$(version_bump_patch "v1.2.3")"

# version_bump_patch_skip
assert_eq "version_bump_patch_skip 0.4.20" "0.4.22" "$(version_bump_patch_skip "0.4.20")"
assert_eq "version_bump_patch_skip v1.2.3" "v1.2.5" "$(version_bump_patch_skip "v1.2.3")"

# version_to_tag
assert_eq "version_to_tag 0.4.21" "v0.4.21" "$(version_to_tag "0.4.21")"
assert_eq "version_to_tag v0.4.21" "v0.4.21" "$(version_to_tag "v0.4.21")"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
