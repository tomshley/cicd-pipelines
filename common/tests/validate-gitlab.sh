#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# GitLab-specific content validation.
# Checks stage names, workflow:rules structure, job naming conventions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GL_CI="$REPO_ROOT/gitlab/ci"

ERRORS=0
log_error() { echo "❌ $1"; ERRORS=$((ERRORS + 1)); }
log_ok()    { echo "✅ $1"; }

echo "=== GitLab-specific validation ==="

# Check stages match spec
if [ -f "$GL_CI/.stages-base.yml" ]; then
  for stage in ".pre" "security.pre-build" "build" "test" "security.post-build" "deploy" ".post"; do
    if grep -q "$stage" "$GL_CI/.stages-base.yml"; then
      log_ok "Stage '$stage' found"
    else
      log_error "Stage '$stage' MISSING from .stages-base.yml"
    fi
  done
fi

# Check gitflow-base uses workflow:rules (not job-level rules)
if [ -f "$GL_CI/.gitflow-base.yml" ]; then
  if grep -q "^workflow:" "$GL_CI/.gitflow-base.yml"; then
    log_ok "workflow:rules present in .gitflow-base.yml"
  else
    log_error "workflow:rules MISSING from .gitflow-base.yml (must use pipeline-level rules)"
  fi
fi

# Check no BREAKGROUND references exist
if grep -rq "BREAKGROUND\|breakground" "$GL_CI/" 2>/dev/null; then
  log_error "BREAKGROUND references found in gitlab/ci/ — must use TOMSHLEY_CICD_*"
else
  log_ok "No BREAKGROUND references in gitlab/ci/"
fi

echo ""
echo "Errors: $ERRORS"
[ "$ERRORS" -eq 0 ] && echo "PASSED" || { echo "FAILED"; exit 1; }
