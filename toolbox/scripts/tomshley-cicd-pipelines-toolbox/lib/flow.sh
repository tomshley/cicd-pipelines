#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Flow preamble — sourced by all flow/*.sh scripts.
# Validates flow-specific environment before any git operations.
# Requires lib/log.sh to be sourced first (for log_warn).

# Warn if FLOW_PUSH_TOKEN is set but FLOW_PUSH_USER is missing.
# The token goes unused without a matching user (URL rewrite requires both).
if [ -n "${TOMSHLEY_CICD_FLOW_PUSH_TOKEN:-}" ] && [ -z "${TOMSHLEY_CICD_FLOW_PUSH_USER:-}" ]; then
  log_warn "TOMSHLEY_CICD_FLOW_PUSH_TOKEN is set but TOMSHLEY_CICD_FLOW_PUSH_USER is empty — token not applied"
  log_warn "    GitLab adapter provides a default; on Bitbucket set FLOW_PUSH_USER to your username"
fi

# Resolve TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX for flow-generated commit messages.
# Precedence:
#   1. TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX — explicit value, used verbatim.
#   2. TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_PATTERN — POSIX extended regex matched
#      against recent commit subjects on the current HEAD; the first match
#      becomes the prefix. Useful for propagating an issue-tracker key already
#      present in the branch history (e.g. 'PROJ-[0-9]+' or '#[0-9]+') into
#      flow-generated merge/tag/bump messages — for example to satisfy a
#      commit-message verification rule — without hardcoding a key.
#      Scan depth is controlled by TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_SCAN_DEPTH
#      (default: 20 commits).
#   3. Empty — no prefix (default behavior).
# Call after the working branch has been checked out.
flow_resolve_message_prefix() {
  if [ -n "${TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX:-}" ]; then
    return 0
  fi
  if [ -z "${TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_PATTERN:-}" ]; then
    return 0
  fi
  _flow_prefix_scan_depth="${TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_SCAN_DEPTH:-20}"
  TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX="$(git log -n "${_flow_prefix_scan_depth}" --format=%s 2>/dev/null \
    | grep -oE "${TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_PATTERN}" \
    | head -n 1 || true)"
  if [ -n "${TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX}" ]; then
    echo "Derived flow message prefix from recent commits: ${TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX}"
  else
    log_warn "TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_PATTERN matched nothing in last ${_flow_prefix_scan_depth} commit subjects — proceeding without prefix"
  fi
  unset _flow_prefix_scan_depth
}
