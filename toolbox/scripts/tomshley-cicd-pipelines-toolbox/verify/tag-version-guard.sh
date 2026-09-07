#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Verify: on a tag pipeline, the tag (with any leading "v" stripped) must equal
# the project's VERSION file. Fails closed on a mismatch so a mis-tagged
# release can never publish. A no-op on branch pipelines and for projects
# without a VERSION file.
#
# Optional env vars (set by adapter YAML):
#   TOMSHLEY_CICD_TAG          — tag name (empty on branch pipelines)
#   TOMSHLEY_CICD_PROJECT_DIR  — project root (default: current directory)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"

version_file="${TOMSHLEY_CICD_PROJECT_DIR:-.}/VERSION"
[ -n "${TOMSHLEY_CICD_TAG:-}" ] && [ -f "$version_file" ] || exit 0

expected="$(tr -d '[:space:]' < "$version_file")"
actual="${TOMSHLEY_CICD_TAG#v}"
[ "$expected" = "$actual" ] || log_fatal "tag/VERSION mismatch: tag=${actual} VERSION=${expected}"
log_info "tag ${TOMSHLEY_CICD_TAG} matches VERSION ${expected}"
