#!/usr/bin/env sh
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Secrets Bootstrap: GitLab Secure Files
#
# Downloads project-level Secure Files from GitLab into .secure_files/.
# toolbox-entry.sh then sources .secure_files/.env if present.
#
# Contract:
#   - Populate .secure_files/ with secrets for the current CI job.
#   - Exit 0 on success OR when no Secure Files are configured (graceful no-op).
#   - Exit 0 when TOMSHLEY_CICD_SECRETS_BOOTSTRAP=false (opt-out).
#
# Override:
#   Consumers can override .tomshley-cicd-secure-files in their .gitlab-ci.yml
#   to use a different secrets provider (Delinea, Vault, etc.). The only
#   contract is: populate .secure_files/ before toolbox-entry.sh runs.
#
# Variables:
#   TOMSHLEY_CICD_SECRETS_BOOTSTRAP — "true" (default) or "false" to skip
#
# Note: download-secure-files is deprecated in GitLab 18.6+.
# Migrate to `glab securefile download` when available in runner images.
# ---------------------------------------------------------------------------

set -eu

# Guard: opt-out via variable
if [ "${TOMSHLEY_CICD_SECRETS_BOOTSTRAP:-true}" != "true" ]; then
  echo "INFO:  Secrets bootstrap skipped (TOMSHLEY_CICD_SECRETS_BOOTSTRAP=${TOMSHLEY_CICD_SECRETS_BOOTSTRAP})"
  exit 0
fi

if [ -z "${CI_PROJECT_ID:-}" ] || [ -z "${CI_JOB_TOKEN:-}" ]; then
  echo "WARN:  GitLab CI variables CI_PROJECT_ID/CI_JOB_TOKEN missing — skipping GitLab Secure Files download" >&2
  exit 0
fi

# GitLab Secure Files installer (pinned commit for reproducibility)
SECURE_FILES_INSTALLER="https://gitlab.com/gitlab-org/incubation-engineering/mobile-devops/download-secure-files/-/raw/e4bb0eaefc5a8514478dfa0113e859652a990d47/installer"

if command -v curl >/dev/null 2>&1 && command -v bash >/dev/null 2>&1; then
  _secure_files_installer="$(mktemp 2>/dev/null || printf '/tmp/tomshley_secure_files_installer.%s' "$$")"
  if curl --fail --silent --show-error -o "${_secure_files_installer}" "${SECURE_FILES_INSTALLER}"; then
    bash "${_secure_files_installer}" || {
      echo "WARN:  GitLab Secure Files installer execution failed — continuing" >&2
    }
  else
    echo "WARN:  GitLab Secure Files installer download failed — continuing" >&2
  fi
  rm -f "${_secure_files_installer}"
else
  echo "WARN:  curl or bash not available — skipping GitLab Secure Files download" >&2
fi
