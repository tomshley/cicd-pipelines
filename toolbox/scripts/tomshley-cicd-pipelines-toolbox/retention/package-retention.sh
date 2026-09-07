#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Retention: delete build-channel packages older than the retention window.
#
# Applies the same rule the container registry cleanup policy uses (see
# README "Container Registry Cleanup Policy"): release versions (digits and
# dots only) and rolling versions (ending in "latest") are kept forever;
# everything else is a pinnable build artifact and is deleted once older than
# TOMSHLEY_CICD_RETENTION_DAYS. Intended for scheduled pipelines.
#
# Optional env vars (set by consumer):
#   TOMSHLEY_CICD_RETENTION_DAYS       — age threshold in days (default: 30)
#
# Required env vars (set by adapter YAML):
#   TOMSHLEY_CICD_PACKAGES_API_URL     — package collection URL
#   TOMSHLEY_CICD_PUBLISH_AUTH_HEADER  — complete HTTP auth header
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/tools.sh"
source "$TOOLBOX_DIR/lib/packages.sh"

: "${TOMSHLEY_CICD_RETENTION_DAYS:=30}"
: "${TOMSHLEY_CICD_PACKAGES_API_URL:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_PUBLISH_AUTH_HEADER:?required — set by adapter YAML}"
tools_require python3 python3

decisions="$(packages_list | RETENTION_DAYS="${TOMSHLEY_CICD_RETENTION_DAYS}" python3 -c '
import json, os, re, sys
from datetime import datetime, timedelta, timezone

RELEASE = re.compile(r"^\d+(\.\d+)*$")
cutoff = datetime.now(timezone.utc) - timedelta(days=int(os.environ["RETENTION_DAYS"]))
for package in json.load(sys.stdin):
    package_id, version, created = package["id"], package.get("version", ""), package.get("created_at", "")
    if not version or not created:
        continue
    if RELEASE.match(version):
        print(f"KEEP release {package_id} {version}")
    elif version.endswith("latest"):
        print(f"KEEP rolling {package_id} {version}")
    elif datetime.fromisoformat(created.replace("Z", "+00:00")) < cutoff:
        print(f"DELETE pinnable {package_id} {version}")
    else:
        print(f"KEEP recent {package_id} {version}")
')"
printf '%s\n' "$decisions"

deleted=0
while read -r action _ package_id version; do
  [ "$action" = DELETE ] || continue
  packages_delete "$package_id"
  log_info "deleted ${package_id} ${version}"
  deleted=$((deleted + 1))
done <<< "$decisions"
log_info "retention complete — ${deleted} package(s) older than ${TOMSHLEY_CICD_RETENTION_DAYS} days deleted"
