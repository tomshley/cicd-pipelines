#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Toolbox Entry Point
# This script is SOURCE'd (not executed) — it sets up the git environment
# for all toolbox scripts (flow, mirror, etc.).
#
# It consumes ONLY TOMSHLEY_CICD_* variables — no platform-native variables
# (CI_*, GITLAB_*, BITBUCKET_*, etc.). The CI adapter YAML is responsible
# for mapping platform-native variables into the canonical interface.
#
# Required environment variables (set by adapter YAML):
#   TOMSHLEY_CICD_PROJECT_DIR      — Project root directory
#   TOMSHLEY_CICD_PROJECT_URL      — Project URL (https://host/path, no .git suffix)
#   TOMSHLEY_CICD_GIT_PUSH_TOKEN   — Access token with write scope
#   TOMSHLEY_CICD_GIT_PUSH_USER    — Username for git push authentication
#   TOMSHLEY_CICD_GIT_USER_EMAIL   — Git commit author email
#   TOMSHLEY_CICD_GIT_USER_NAME    — Git commit author display name
#
# Optional environment variables (set by adapter YAML):
#   TOMSHLEY_CICD_CURRENT_BRANCH   — Current branch name (empty on tag pipelines)
#   TOMSHLEY_CICD_TAG              — Tag name (empty on branch pipelines)
#
# Derived (exported by this script):
#   TOMSHLEY_CICD_IS_TAG           — "true" if TOMSHLEY_CICD_TAG is non-empty

_TOOLBOX_ENTRY_OLDOPTS=$(set +o); set -euo pipefail
_toolbox_entry_restore() { eval "$_TOOLBOX_ENTRY_OLDOPTS"; unset _TOOLBOX_ENTRY_OLDOPTS; trap - RETURN ERR; }
trap '_toolbox_entry_restore' ERR RETURN
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/git.sh"

# Validate required variables
: "${TOMSHLEY_CICD_PROJECT_DIR:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_PROJECT_URL:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_GIT_PUSH_TOKEN:?required — set by adapter YAML or CI/CD settings}"
: "${TOMSHLEY_CICD_GIT_PUSH_USER:?required — set by adapter YAML or CI/CD settings}"
: "${TOMSHLEY_CICD_GIT_USER_EMAIL:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_GIT_USER_NAME:?required — set by adapter YAML}"

# Enter project directory
cd "${TOMSHLEY_CICD_PROJECT_DIR}"

# Source secure-files .env if present (opinionated secret delivery)
if [ -f ".secure_files/.env" ]; then
  set -a
  . .secure_files/.env
  set +a
fi

# Neutralize LFS so hooks/filters don't block gitflow operations
git_neutralize_lfs

# Configure git user identity
git_configure_user "${TOMSHLEY_CICD_GIT_USER_EMAIL}" "${TOMSHLEY_CICD_GIT_USER_NAME}"

# Set authenticated remote URL via GIT_ASKPASS (avoids embedding token in .git/config)
# NOTE: TOMSHLEY_CICD_PROJECT_URL must NOT contain embedded credentials (user@host);
# adapter YAMLs guarantee this (CI_PROJECT_URL, BITBUCKET_REPO_FULL_NAME are bare).
URL_NO_SCHEME=$(echo "${TOMSHLEY_CICD_PROJECT_URL}" | sed -E 's|https?://||')
URL_NO_SCHEME="${URL_NO_SCHEME%.git}"
git remote set-url origin "https://${TOMSHLEY_CICD_GIT_PUSH_USER}@${URL_NO_SCHEME}.git"
_TOOLBOX_ASKPASS=$(mktemp)
chmod 700 "$_TOOLBOX_ASKPASS"
printf '#!/bin/sh\necho "${TOMSHLEY_CICD_GIT_PUSH_TOKEN}"\n' > "$_TOOLBOX_ASKPASS"
export GIT_ASKPASS="$_TOOLBOX_ASKPASS"
export GIT_TERMINAL_PROMPT=0

# Persist tempfile path so after_script (separate shell context) can clean up.
# GitLab/Bitbucket after_script does NOT inherit exports from script phase,
# so export -f and $_TOOLBOX_ASKPASS are unavailable there. Writing the path
# to a known file lets the after_script find and remove the tempfile.
echo "$_TOOLBOX_ASKPASS" > /tmp/.toolbox_askpass_path

# Cleanup function — usable from script phase directly; after_script should
# use: rm -f "$(cat /tmp/.toolbox_askpass_path 2>/dev/null)" /tmp/.toolbox_askpass_path 2>/dev/null || true
toolbox_cleanup() {
  rm -f "${_TOOLBOX_ASKPASS:-}" /tmp/.toolbox_askpass_path 2>/dev/null || true
  unset GIT_ASKPASS _TOOLBOX_ASKPASS
}
export -f toolbox_cleanup

# Derive tag detection from TOMSHLEY_CICD_TAG presence
: "${TOMSHLEY_CICD_CURRENT_BRANCH:=}"
: "${TOMSHLEY_CICD_TAG:=}"
if [ -n "${TOMSHLEY_CICD_TAG}" ]; then
  export TOMSHLEY_CICD_IS_TAG="true"
else
  export TOMSHLEY_CICD_IS_TAG="false"
fi

# Re-export for downstream scripts
export TOMSHLEY_CICD_PROJECT_DIR
export TOMSHLEY_CICD_CURRENT_BRANCH
export TOMSHLEY_CICD_TAG

# Shell options are restored automatically by the RETURN trap (line 31)
