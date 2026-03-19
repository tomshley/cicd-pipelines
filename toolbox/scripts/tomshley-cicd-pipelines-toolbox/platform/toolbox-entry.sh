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
# Auth: By default, CI platforms provide push auth natively (GitLab
# CI_REPOSITORY_URL, Bitbucket BITBUCKET_GIT_HTTP_ORIGIN). Enable push
# permissions in your CI settings:
#   GitLab:    Settings → CI/CD → Token permissions → Allow Git push
#   Bitbucket: Push back works by default (HTTP origin is preconfigured)
#
# On GitLab, CI_JOB_TOKEN pushes do NOT trigger downstream pipelines
# (anti-cascade protection). To enable pipeline triggering on pushed
# branches/tags, set TOMSHLEY_CICD_FLOW_PUSH_TOKEN to a Project Access
# Token with write_repository scope. The adapter YAML provides a
# platform-appropriate default for TOMSHLEY_CICD_FLOW_PUSH_USER.
#
# Required environment variables (set by adapter YAML):
#   TOMSHLEY_CICD_PROJECT_DIR      — Project root directory
#   TOMSHLEY_CICD_GIT_USER_EMAIL   — Git commit author email
#   TOMSHLEY_CICD_GIT_USER_NAME    — Git commit author display name
#
# Optional environment variables (set by adapter YAML):
#   TOMSHLEY_CICD_CURRENT_BRANCH   — Current branch name (empty on tag pipelines)
#   TOMSHLEY_CICD_TAG              — Tag name (empty on branch pipelines)
#   TOMSHLEY_CICD_FLOW_PUSH_TOKEN  — Token for git push (PAT, App Password, etc.)
#   TOMSHLEY_CICD_FLOW_PUSH_USER   — Username for git push auth (default per platform)
#
# Derived (exported by this script):
#   TOMSHLEY_CICD_IS_TAG           — "true" if TOMSHLEY_CICD_TAG is non-empty

if [ -n "${BASH_VERSION:-}" ]; then
  _TOOLBOX_ENTRY_OLDOPTS=$(set +o); set -euo pipefail
  _toolbox_entry_restore() { eval "$_TOOLBOX_ENTRY_OLDOPTS"; unset _TOOLBOX_ENTRY_OLDOPTS; trap - RETURN ERR; }
  trap '_toolbox_entry_restore' ERR RETURN
else
  # POSIX fallback: no pipefail, no RETURN trap
  set -eu
fi
if [ -n "${BASH_VERSION:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="${TOMSHLEY_CICD_TOOLBOX_ROOT:-/opt/tomshley-cicd-pipelines-toolbox}/platform"
fi
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/git.sh"

# Validate required variables
: "${TOMSHLEY_CICD_PROJECT_DIR:?required — set by adapter YAML}"
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

# Clear any credential helpers/extraheaders injected by the CI runner
# (e.g. FF_USE_GIT_PROACTIVE_AUTH) to prevent them from being sent to
# non-origin remotes such as HTTPS mirror targets.
git config --global --unset-all http.extraheader 2>/dev/null || true

# Optional: rewrite origin URL with explicit credentials for flow push.
# This enables pipeline triggering on platforms where CI token pushes
# don't trigger downstream pipelines (e.g. GitLab anti-cascade protection).
# If FLOW_PUSH_TOKEN is not set, native CI clone URL credentials are used.
if [ -n "${TOMSHLEY_CICD_FLOW_PUSH_TOKEN:-}" ] && [ -n "${TOMSHLEY_CICD_FLOW_PUSH_USER:-}" ]; then
  _ORIGIN_URL=$(git remote get-url origin)
  case "$_ORIGIN_URL" in
    https://*)
      # Strip existing credentials (everything between :// and last @)
      _ORIGIN_URL="${_ORIGIN_URL#https://}"
      _ORIGIN_URL="${_ORIGIN_URL##*@}"
      _ORIGIN_URL="https://${TOMSHLEY_CICD_FLOW_PUSH_USER}:${TOMSHLEY_CICD_FLOW_PUSH_TOKEN}@${_ORIGIN_URL}"
      git remote set-url origin "$_ORIGIN_URL"
      ;;
    *)
      _SCHEME="${_ORIGIN_URL%%://*}"
      if [ "$_SCHEME" = "$_ORIGIN_URL" ]; then
        _SCHEME="(non-scheme, e.g. SCP-style SSH)"
      else
        _SCHEME="${_SCHEME}://"
      fi
      log_warn "TOMSHLEY_CICD_FLOW_PUSH_TOKEN is set but origin URL is not HTTPS — token not applied"
      log_warn "    Origin URL scheme: ${_SCHEME}"
      unset _SCHEME
      ;;
  esac
  unset _ORIGIN_URL
fi

# Prevent git from prompting for credentials interactively (fail fast instead)
export GIT_TERMINAL_PROMPT=0

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
export TOMSHLEY_CICD_IS_TAG

# Shell options are restored automatically by the RETURN trap (line 31)
