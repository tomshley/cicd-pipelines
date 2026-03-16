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
