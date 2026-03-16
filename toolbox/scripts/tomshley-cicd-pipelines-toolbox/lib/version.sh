#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# VERSION file helpers for cicd-pipelines toolbox scripts.
# Source this file; do not execute directly.
#
# Every function reads from arguments and prints to stdout.
# Fatal errors call log_fatal (requires lib/log.sh to be sourced first).

# Read VERSION file, strip whitespace. Fatal if file missing or empty.
# Usage: version_read /path/to/VERSION
version_read() {
  local file="$1"
  if [ ! -f "$file" ]; then
    log_fatal "VERSION file not found at ${file} — aborting"
  fi
  local ver
  ver=$(tr -d '[:space:]' < "$file")
  if [ -z "$ver" ]; then
    log_fatal "VERSION file at ${file} is empty — aborting"
  fi
  echo "$ver"
}

# Validate that a version string matches semver pattern (with optional v prefix).
# Fatal if invalid.
# Usage: version_validate "0.4.20"
version_validate() {
  local ver="$1"
  if ! echo "$ver" | grep -qE '^v?[0-9]+\.[0-9]+\.[0-9]+$'; then
    log_fatal "VERSION content '${ver}' is not valid version format — aborting"
  fi
}

# Print "v" if version starts with v, else print empty string.
# Usage: prefix=$(version_prefix "v1.2.3")
version_prefix() {
  local ver="$1"
  case "$ver" in v*) echo "v" ;; *) echo "" ;; esac
}

# Print version without leading v.
# Usage: clean=$(version_strip "v1.2.3")  # prints "1.2.3"
version_strip() {
  local ver="$1"
  echo "${ver#v}"
}

# Bump patch component by 1, preserving prefix.
# Usage: next=$(version_bump_patch "0.4.20")  # prints "0.4.21"
# Usage: next=$(version_bump_patch "v1.2.3")  # prints "v1.2.4"
version_bump_patch() {
  local ver="$1"
  local prefix
  prefix=$(version_prefix "$ver")
  local clean
  clean=$(version_strip "$ver")
  local bumped
  bumped=$(echo "$clean" | awk 'BEGIN{FS=OFS="."} {$NF++; print}')
  echo "${prefix}${bumped}"
}

# Bump patch component by 2 (skip one version), preserving prefix.
# Usage: next=$(version_bump_patch_skip "0.4.20")  # prints "0.4.22"
version_bump_patch_skip() {
  local ver="$1"
  local prefix
  prefix=$(version_prefix "$ver")
  local clean
  clean=$(version_strip "$ver")
  local bumped
  bumped=$(echo "$clean" | awk 'BEGIN{FS=OFS="."} {$NF+=2; print}')
  echo "${prefix}${bumped}"
}

# Always print v + stripped version (canonical tag format).
# Usage: tag=$(version_to_tag "0.4.21")   # prints "v0.4.21"
# Usage: tag=$(version_to_tag "v0.4.21")  # prints "v0.4.21"
version_to_tag() {
  local ver="$1"
  local clean
  clean=$(version_strip "$ver")
  echo "v${clean}"
}
