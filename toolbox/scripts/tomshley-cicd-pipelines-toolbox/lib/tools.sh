#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Tool presence checks for toolbox recipes. Mirrors the adapters'
# ensure-tools fragment: a no-op when the runner image already provides the
# tool, an Alpine package install when it does not, and an explicit failure
# when neither is possible.
# Source this file; do not execute directly.

# tools_require <command> <apk packages...>
tools_require() {
  local cmd="$1"; shift
  command -v "$cmd" >/dev/null 2>&1 && return 0
  if command -v apk >/dev/null 2>&1; then
    echo "INFO:  ${cmd} missing from the runner image — installing: $*"
    apk add --no-cache "$@"
    return 0
  fi
  echo "ERROR: ${cmd} is required but missing and apk is unavailable; use a runner image that provides it" >&2
  return 1
}
