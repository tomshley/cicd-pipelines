#!/usr/bin/env sh
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Secrets Bootstrap: Delinea (placeholder)
#
# Future implementation: fetch secrets from Delinea and populate .secure_files/.
# toolbox-entry.sh then sources .secure_files/.env if present.
#
# Contract:
#   - Populate .secure_files/ with secrets for the current CI job.
#   - Exit 0 on success OR when not configured (graceful no-op).
#   - Exit 0 when TOMSHLEY_CICD_SECRETS_BOOTSTRAP=false (opt-out).
#
# Usage:
#   Override .tomshley-cicd-secure-files in your .gitlab-ci.yml:
#
#     .tomshley-cicd-secure-files:
#       before_script:
#         - /opt/tomshley-cicd-pipelines-toolbox/secrets/delinea.sh
#
# Variables:
#   TOMSHLEY_CICD_SECRETS_BOOTSTRAP — "true" (default) or "false" to skip
#
# TODO: Implement Delinea API integration
# ---------------------------------------------------------------------------

set -eu

# Guard: opt-out via variable
if [ "${TOMSHLEY_CICD_SECRETS_BOOTSTRAP:-true}" != "true" ]; then
  echo "INFO:  Secrets bootstrap skipped (TOMSHLEY_CICD_SECRETS_BOOTSTRAP=${TOMSHLEY_CICD_SECRETS_BOOTSTRAP})"
  exit 0
fi

echo "WARN:  Delinea secrets bootstrap is not yet implemented — no secrets fetched" >&2
echo "WARN:  Override .tomshley-cicd-secure-files with gitlab-secure-files.sh or implement this script" >&2

exit 0

