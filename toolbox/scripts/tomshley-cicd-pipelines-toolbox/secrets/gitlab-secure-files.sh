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
# Implementation:
#   Uses the GitLab REST API directly (GET /projects/:id/secure_files).
#   The deprecated download-secure-files binary (removed in GitLab 18.6+)
#   is no longer used.  Requires curl and either jq or python3 for JSON
#   parsing.
#
#   Why not `glab securefile download`?
#   Runner images are platform-agnostic (GitLab + Bitbucket).  Adding the
#   glab CLI would bake a GitLab-only tool into shared images.  The REST
#   API approach uses curl + jq which are already present for other
#   cross-platform purposes.
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

if ! command -v curl >/dev/null 2>&1; then
  echo "WARN:  curl not available — skipping GitLab Secure Files download" >&2
  exit 0
fi

# Select a JSON parser — jq preferred, python3 fallback
if command -v jq >/dev/null 2>&1; then
  _json_id_name() { jq -r '.[] | "\(.id)\t\(.name)"'; }
  _json_length()  { jq 'length'; }
elif command -v python3 >/dev/null 2>&1; then
  _json_id_name() { python3 -c "import json,sys;[print(str(f['id'])+'\t'+f['name']) for f in json.load(sys.stdin)]"; }
  _json_length()  { python3 -c "import json,sys;print(len(json.load(sys.stdin)))"; }
else
  echo "WARN:  Neither jq nor python3 available — cannot parse Secure Files API response" >&2
  exit 0
fi

SECURE_FILES_DIR="${CI_PROJECT_DIR:-.}/.secure_files"
mkdir -p "${SECURE_FILES_DIR}"

API_URL="${CI_API_V4_URL:-https://gitlab.com/api/v4}"
_base="${API_URL}/projects/${CI_PROJECT_ID}/secure_files"
_page=1

echo "Downloading Secure Files to ${SECURE_FILES_DIR}"

while :; do
  _resp=$(curl --fail --silent --show-error \
    --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
    "${_base}?per_page=100&page=${_page}") || {
    echo "WARN:  Secure Files API list request failed (page ${_page}) — continuing" >&2
    break
  }

  # Empty page → done
  case "${_resp}" in "[]"|"") break ;; esac

  printf '%s' "${_resp}" | _json_id_name | while IFS="$(printf '\t')" read -r _id _name; do
    [ -z "${_id:-}" ] && continue
    if curl --fail --silent --show-error \
      --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
      -o "${SECURE_FILES_DIR}/${_name}" \
      "${_base}/${_id}/download"; then
      echo "${_name} downloaded to ${SECURE_FILES_DIR}/${_name}"
    else
      echo "WARN:  Failed to download secure file ${_name} (id=${_id})" >&2
    fi
  done

  _count=$(printf '%s' "${_resp}" | _json_length)
  [ "${_count}" -lt 100 ] && break
  _page=$((_page + 1))
done
