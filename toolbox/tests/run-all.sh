#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Runs all toolbox tests. Exits non-zero if any fail.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOTAL_PASS=0
TOTAL_FAIL=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  echo ""
  echo "================================================================"
  echo "Running: $(basename "$test_file")"
  echo "================================================================"
  if bash "$test_file"; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
done

echo ""
echo "================================================================"
echo "Test suites: ${TOTAL_PASS} passed, ${TOTAL_FAIL} failed"
echo "================================================================"

if [ "$TOTAL_FAIL" -gt 0 ]; then
  exit 1
fi
