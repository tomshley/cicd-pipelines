#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Publish: upload one artifact file to a generic package registry under every
# label the artifact policy selects (pinnable + rolling on branches, the
# clean version on tags).
#
# Required env vars (set by consumer):
#   TOMSHLEY_CICD_GENERIC_PACKAGE            — package name in the registry
#   TOMSHLEY_CICD_GENERIC_ARTIFACT           — path of the file to upload
#
# Required env vars (set by adapter YAML):
#   TOMSHLEY_CICD_GENERIC_UPLOAD_URL_TEMPLATE — printf template receiving
#                                              package, version, filename
#   TOMSHLEY_CICD_PUBLISH_AUTH_HEADER        — complete HTTP auth header
#   TOMSHLEY_CICD_TAG / _REF_SLUG / _COMMIT_SHA — see platform/publish-policy.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"

: "${TOMSHLEY_CICD_GENERIC_PACKAGE:?required — package name in the registry}"
: "${TOMSHLEY_CICD_GENERIC_ARTIFACT:?required — path of the file to upload}"
: "${TOMSHLEY_CICD_GENERIC_UPLOAD_URL_TEMPLATE:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_PUBLISH_AUTH_HEADER:?required — set by adapter YAML}"
[ -f "${TOMSHLEY_CICD_GENERIC_ARTIFACT}" ] || log_fatal "artifact not found: ${TOMSHLEY_CICD_GENERIC_ARTIFACT}"

source "$TOOLBOX_DIR/platform/publish-policy.sh"
bash "$TOOLBOX_DIR/verify/tag-version-guard.sh"

# Keep the artifact's own extension (e.g. "tar.gz"), replace its stem with the label.
basename="${TOMSHLEY_CICD_GENERIC_ARTIFACT##*/}"
case "$basename" in
  *.tar.*) extension="tar.${basename##*.}" ;;
  *.*)     extension="${basename##*.}" ;;
  *)       extension="" ;;
esac

for label in ${CICD_PUBLISH_LABELS}; do
  filename="${TOMSHLEY_CICD_GENERIC_PACKAGE}-${label}${extension:+.$extension}"
  # shellcheck disable=SC2059 — the template is a deliberate printf format
  url="$(printf "${TOMSHLEY_CICD_GENERIC_UPLOAD_URL_TEMPLATE}" "${TOMSHLEY_CICD_GENERIC_PACKAGE}" "$label" "$filename")"
  log_info "uploading ${filename} -> ${url}"
  curl --fail --silent --show-error --header "${TOMSHLEY_CICD_PUBLISH_AUTH_HEADER}" \
    --upload-file "${TOMSHLEY_CICD_GENERIC_ARTIFACT}" "$url"
done
