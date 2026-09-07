#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Verify: a WebJar's packaged version must equal the upstream version it wraps.
# Reads the project's own <version> (never the <parent> or a dependency's)
# and the <upstreamVersion> property from the pom and fails closed when they
# differ or either is missing.
#
# Optional env vars (set by consumer):
#   TOMSHLEY_CICD_WEBJAR_POM   — pom path (default: pom.xml)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/tools.sh"

pom="${TOMSHLEY_CICD_WEBJAR_POM:-pom.xml}"
[ -f "$pom" ] || log_fatal "pom not found: ${pom}"
tools_require python3 python3

versions="$(python3 - "$pom" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
ns = root.tag[: root.tag.index("}") + 1] if root.tag.startswith("{") else ""
packaged = root.findtext(f"{ns}version") or ""
wrapped = root.findtext(f"{ns}properties/{ns}upstreamVersion") or ""
print(packaged.strip())
print(wrapped.strip())
PY
)"
packaged="$(printf '%s\n' "$versions" | sed -n 1p)"
wrapped="$(printf '%s\n' "$versions" | sed -n 2p)"

[ -n "$wrapped" ] && [ -n "$packaged" ] || log_fatal "webjar version metadata missing in ${pom} (need <version> and <properties><upstreamVersion>)"
[ "$wrapped" = "$packaged" ] || log_fatal "webjar pairing mismatch: wrapped=${wrapped} packaged=${packaged}"
log_info "webjar ${packaged} pairs with upstream ${wrapped}"
