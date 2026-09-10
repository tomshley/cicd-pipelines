#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Test: every script entry in an adapter is a command, not a YAML mapping.
#
# A sequence entry under script/before_script/after_script that is unquoted and
# contains ": " parses as a mapping, and the platform rejects the entire
# configuration — for the adapter and for every consumer that includes it. This
# checks the shape with the standard library only, because the test image carries
# no YAML parser.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== test-adapter-script-entries ==="

PASS_COUNT=0
FAIL_COUNT=0

for adapter in "$PROJECT_ROOT"/adapters/*/ci/adapter.yml "$PROJECT_ROOT"/.gitlab-ci.yml; do
  [ -f "$adapter" ] || continue
  name="${adapter#"$PROJECT_ROOT/"}"
  if findings="$(python3 "$SCRIPT_DIR/adapter-script-entries.py" "$adapter")"; then
    echo "  PASS: $name has no ambiguous script entries"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $name has script entries that parse as YAML mappings"
    echo "$findings" | sed 's/^/    /'
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
