#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Mirror: sync branches and tags to a secondary remote.
# Safe no-op when TOMSHLEY_CICD_MIRROR_URL is empty.
#
# Required env vars (set by platform script):
#   TOMSHLEY_CICD_CURRENT_BRANCH — current branch (empty on tag pipelines)
#   TOMSHLEY_CICD_IS_TAG         — "true" or "false"
#   TOMSHLEY_CICD_TAG            — tag name (empty on branch pipelines)
#
# Optional env vars (set by consumer):
#   TOMSHLEY_CICD_MIRROR_URL         — remote URL (empty = no-op)
#   TOMSHLEY_CICD_MIRROR_BRANCHES    — comma-separated branch list (default: "main")
#   TOMSHLEY_CICD_MIRROR_BRANCH_MAP  — comma-separated src:dst pairs (overrides BRANCHES)
#   TOMSHLEY_CICD_MIRROR_TAGS        — mirror tags: true/false (default: "true")
#   TOMSHLEY_CICD_MIRROR_SSH_KEY     — path to SSH key file
#   TOMSHLEY_CICD_MIRROR_FORCE_PUSH  — use --force (default: "true")
set -euo pipefail
if [ -n "${BASH_VERSION:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="${TOMSHLEY_CICD_TOOLBOX_ROOT:-/opt/tomshley-cicd-pipelines-toolbox}/mirror"
fi
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"

: "${TOMSHLEY_CICD_MIRROR_URL:=}"
: "${TOMSHLEY_CICD_MIRROR_BRANCHES:=main}"
: "${TOMSHLEY_CICD_MIRROR_BRANCH_MAP:=}"
: "${TOMSHLEY_CICD_MIRROR_TAGS:=true}"
: "${TOMSHLEY_CICD_MIRROR_SSH_KEY:=}"
: "${TOMSHLEY_CICD_MIRROR_FORCE_PUSH:=true}"
: "${TOMSHLEY_CICD_CURRENT_BRANCH:=}"
: "${TOMSHLEY_CICD_IS_TAG:=false}"
: "${TOMSHLEY_CICD_TAG:=}"

if [ -z "${TOMSHLEY_CICD_MIRROR_URL}" ]; then
  echo "TOMSHLEY_CICD_MIRROR_URL is not set — skipping mirror sync"
  exit 0
fi

# --- SSH key setup (only for SSH URLs) ---
if [ -n "${TOMSHLEY_CICD_MIRROR_SSH_KEY}" ]; then
  if [ ! -f "${TOMSHLEY_CICD_MIRROR_SSH_KEY}" ]; then
    log_warn "TOMSHLEY_CICD_MIRROR_SSH_KEY is set to '${TOMSHLEY_CICD_MIRROR_SSH_KEY}' but file not found"
    log_warn "    Did you upload it via GitLab Secure Files?"
  elif echo "${TOMSHLEY_CICD_MIRROR_URL}" | grep -qE '^(git@|ssh://)'; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    touch ~/.ssh/known_hosts
    cp "${TOMSHLEY_CICD_MIRROR_SSH_KEY}" ~/.ssh/mirror_key
    chmod 600 ~/.ssh/mirror_key
    # Extract host from SSH URL (supports IPv6 bracket notation)
    MIRROR_HOST=$(echo "${TOMSHLEY_CICD_MIRROR_URL}" | sed -E '
      s|^git@\[([^]]+)\]:.*|\1|;
      s|^git@([^:]+):.*|\1|;
      s|^ssh://([^@]+@)?\[([^]]+)\].*|\2|;
      s|^ssh://([^@]+@)?([^/:]+).*|\2|
    ')
    if [ -n "${MIRROR_HOST}" ] && ! echo "${MIRROR_HOST}" | grep -q '/'; then
      ssh-keyscan -H "${MIRROR_HOST}" >> ~/.ssh/known_hosts 2>/dev/null || true
      export GIT_SSH_COMMAND="ssh -i ~/.ssh/mirror_key -o StrictHostKeyChecking=accept-new"
    else
      log_warn "Could not extract host from MIRROR_URL for SSH setup"
    fi
  else
    log_warn "TOMSHLEY_CICD_MIRROR_SSH_KEY is set but MIRROR_URL is not SSH — key will be ignored"
  fi
fi

# --- Add mirror remote ---
git remote add mirror "${TOMSHLEY_CICD_MIRROR_URL}" 2>/dev/null || git remote set-url mirror "${TOMSHLEY_CICD_MIRROR_URL}"
# Fetch from mirror to update refs and avoid "stale info" errors
git fetch mirror --prune --prune-tags 2>/dev/null || true

# --- Sync logic ---
echo "=== Mirror Sync ==="
# Sanitize URL for logging (strip embedded credentials if present)
SAFE_MIRROR_URL=$(echo "${TOMSHLEY_CICD_MIRROR_URL}" | sed -E 's|://[^@]+@|://***@|')
echo "Mirror URL:   ${SAFE_MIRROR_URL}"
if [ -n "${TOMSHLEY_CICD_MIRROR_BRANCH_MAP}" ]; then
  echo "Branch map:   ${TOMSHLEY_CICD_MIRROR_BRANCH_MAP}"
else
  echo "Branches:     ${TOMSHLEY_CICD_MIRROR_BRANCHES}"
fi
echo "Mirror tags:  ${TOMSHLEY_CICD_MIRROR_TAGS}"
echo "Force push:   ${TOMSHLEY_CICD_MIRROR_FORCE_PUSH}"

# Determine push flags
if [ "${TOMSHLEY_CICD_MIRROR_FORCE_PUSH}" = "true" ]; then
  PUSH_FLAGS="--force"
else
  PUSH_FLAGS="--force-with-lease"
fi

# Fetch latest refs from origin
# --prune-tags only on branch pipelines; on tag pipelines the current
# tag may not yet exist on the remote and would be deleted locally.
if [ "${TOMSHLEY_CICD_IS_TAG}" = "true" ]; then
  git fetch --prune origin
else
  git fetch --prune --prune-tags origin
fi

PUSHED=0
FAILED=0

# Push matching branches
if [ -n "${TOMSHLEY_CICD_CURRENT_BRANCH}" ]; then
  if [ -n "${TOMSHLEY_CICD_MIRROR_BRANCH_MAP}" ]; then
    # Branch map mode: parse src:dst pairs
    OLD_IFS="$IFS"
    IFS=','
    for mapping in ${TOMSHLEY_CICD_MIRROR_BRANCH_MAP}; do
      mapping=$(echo "$mapping" | tr -d '[:space:]')
      src=$(echo "$mapping" | cut -d: -f1)
      dst=$(echo "$mapping" | cut -d: -f2)
      if [ -z "$src" ]; then
        log_warn "Ignoring malformed branch mapping '${mapping}' (empty source)"
        continue
      fi
      if [ -z "$dst" ]; then
        dst="$src"
      fi
      # Glob-pattern matching: bash `case` accepts shell globs in the pattern.
      # When src contains wildcards (e.g. 'develop-*'), the actual current branch
      # name is used as the source ref. If dst contains '*', it identity-maps
      # to the current branch name (preserves contributor branch naming).
      matched=false
      case "${TOMSHLEY_CICD_CURRENT_BRANCH}" in
        $src) matched=true ;;
      esac
      if [ "$matched" = "true" ]; then
        actual_src="${TOMSHLEY_CICD_CURRENT_BRANCH}"
        actual_dst="$dst"
        case "$dst" in
          *\**) actual_dst="${TOMSHLEY_CICD_CURRENT_BRANCH}" ;;
        esac
        echo "Pushing branch: ${actual_src} → ${actual_dst} (${PUSH_FLAGS})"
        git fetch origin "+refs/heads/${actual_src}:refs/remotes/origin/${actual_src}" 2>/dev/null || true
        if git push mirror "refs/remotes/origin/${actual_src}:refs/heads/${actual_dst}" ${PUSH_FLAGS}; then
          PUSHED=$((PUSHED + 1))
        else
          log_error "Failed to push branch ${actual_src} → ${actual_dst} to mirror"
          FAILED=$((FAILED + 1))
        fi
      fi
    done
    IFS="$OLD_IFS"
    if [ "$PUSHED" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
      echo "Branch '${TOMSHLEY_CICD_CURRENT_BRANCH}' is not in TOMSHLEY_CICD_MIRROR_BRANCH_MAP — skipping"
    fi
  else
    # Simple branch list mode (backward compatible)
    OLD_IFS="$IFS"
    IFS=','
    for branch in ${TOMSHLEY_CICD_MIRROR_BRANCHES}; do
      branch=$(echo "$branch" | tr -d '[:space:]')
      if [ "$branch" = "${TOMSHLEY_CICD_CURRENT_BRANCH}" ]; then
        echo "Pushing branch: ${branch} (${PUSH_FLAGS})"
        # Ensure remote tracking ref exists before pushing
        git fetch origin "+refs/heads/${branch}:refs/remotes/origin/${branch}" 2>/dev/null || true
        if git push mirror "refs/remotes/origin/${branch}:refs/heads/${branch}" ${PUSH_FLAGS}; then
          PUSHED=$((PUSHED + 1))
        else
          log_error "Failed to push branch ${branch} to mirror"
          FAILED=$((FAILED + 1))
        fi
      fi
    done
    IFS="$OLD_IFS"
    if [ "$PUSHED" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
      echo "Branch '${TOMSHLEY_CICD_CURRENT_BRANCH}' is not in TOMSHLEY_CICD_MIRROR_BRANCHES — skipping"
    fi
  fi
fi

# Push tags
if [ "${TOMSHLEY_CICD_MIRROR_TAGS}" = "true" ]; then
  if [ "${TOMSHLEY_CICD_IS_TAG}" = "true" ] && [ -n "${TOMSHLEY_CICD_TAG}" ]; then
    # Tag pipeline: push only this tag
    echo "Pushing tag: ${TOMSHLEY_CICD_TAG} (${PUSH_FLAGS})"
    if git push mirror "refs/tags/${TOMSHLEY_CICD_TAG}:refs/tags/${TOMSHLEY_CICD_TAG}" ${PUSH_FLAGS}; then
      PUSHED=$((PUSHED + 1))
    else
      log_error "Failed to push tag ${TOMSHLEY_CICD_TAG} to mirror"
      FAILED=$((FAILED + 1))
    fi
  elif [ -n "${TOMSHLEY_CICD_CURRENT_BRANCH}" ]; then
    # Branch pipeline: push all tags
    echo "Pushing all tags (${PUSH_FLAGS})"
    if git push mirror --tags ${PUSH_FLAGS}; then
      # Just increment by 1 to indicate tags were synced
      PUSHED=$((PUSHED + 1))
    else
      log_error "Failed to push tags to mirror"
      FAILED=$((FAILED + 1))
    fi
  fi
fi

if [ "$PUSHED" -gt 0 ]; then
  echo "[ok] Mirrored ${PUSHED} ref(s) to ${SAFE_MIRROR_URL}"
else
  echo "No refs matched mirror criteria — nothing pushed"
fi

if [ "$FAILED" -gt 0 ]; then
  log_warn "${FAILED} ref(s) failed to mirror (see errors above)"
fi

# Always exit 0 for allow_failure: true semantics
exit 0
