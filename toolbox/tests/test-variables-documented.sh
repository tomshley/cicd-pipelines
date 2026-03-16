#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Checks that every TOMSHLEY_CICD_* variable used in scripts is documented in VARIABLES.md.
# Prevents undocumented variables from being introduced by commits.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="${TOOLBOX_ROOT}/scripts/tomshley-cicd-pipelines-toolbox"
VARIABLES_MD="${TOOLBOX_ROOT}/VARIABLES.md"

echo "=== test-variables-documented ==="

if [ ! -f "$VARIABLES_MD" ]; then
  echo "FAIL: VARIABLES.md not found at ${VARIABLES_MD}"
  exit 1
fi

# Extract all TOMSHLEY_CICD_* variable names from scripts
# Matches: ${TOMSHLEY_CICD_FOO}, ${TOMSHLEY_CICD_FOO:-default}, $TOMSHLEY_CICD_FOO,
# and : "${TOMSHLEY_CICD_FOO:?required}" patterns
SCRIPT_VARS=$(grep -rhoE 'TOMSHLEY_CICD_[A-Z_]+' "$SCRIPTS_DIR" | sort -u)

# Extract all TOMSHLEY_CICD_* variable names from VARIABLES.md
DOC_VARS=$(grep -oE 'TOMSHLEY_CICD_[A-Z_]+' "$VARIABLES_MD" | sort -u)

FAIL=0
for var in $SCRIPT_VARS; do
  if ! echo "$DOC_VARS" | grep -qx "$var"; then
    echo "  UNDOCUMENTED: ${var} found in scripts but not in VARIABLES.md"
    # Show which files reference it
    grep -rl "$var" "$SCRIPTS_DIR" | while read -r f; do
      echo "    - $(basename "$(dirname "$f")")/$(basename "$f")"
    done
    FAIL=$((FAIL + 1))
  fi
done

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "FAIL: ${FAIL} undocumented variable(s) found"
  echo "Add them to ${VARIABLES_MD}"
  exit 1
else
  echo "  PASS: All TOMSHLEY_CICD_* variables are documented"
fi
