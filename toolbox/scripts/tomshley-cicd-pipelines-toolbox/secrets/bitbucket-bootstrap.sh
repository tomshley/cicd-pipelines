#!/usr/bin/env sh
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Secrets Bootstrap: Bitbucket (default no-op)
#
# Bitbucket Pipelines has no built-in equivalent to GitLab Secure Files.
# This hook preserves the same lifecycle position as the GitLab adapter:
# it runs before toolbox-entry.sh so consumers can replace it with a
# provider that populates .secure_files/.
#
# Contract:
#   - Populate .secure_files/ with secrets for the current CI job.
#   - Exit 0 on success OR when not configured (graceful no-op).
#   - Exit 0 when TOMSHLEY_CICD_SECRETS_BOOTSTRAP=false (opt-out).
#
# Variables:
#   TOMSHLEY_CICD_SECRETS_BOOTSTRAP — "true" (default) or "false" to skip
# ---------------------------------------------------------------------------

set -eu

# Guard: opt-out via variable
if [ "${TOMSHLEY_CICD_SECRETS_BOOTSTRAP:-true}" != "true" ]; then
  echo "INFO:  Secrets bootstrap skipped (TOMSHLEY_CICD_SECRETS_BOOTSTRAP=${TOMSHLEY_CICD_SECRETS_BOOTSTRAP})"
  exit 0
fi

exit 0
