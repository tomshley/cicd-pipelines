#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Publish: run an sbt publish command under the artifact policy.
#
# Resolves the policy, enforces the tag/VERSION guard, exports
# TOMSHLEY_CICD_BUILD_REVISION=$CICD_PUBLISH_PINNABLE_TAG (empty on tags, so
# the build publishes its clean version), then runs the command given as
# arguments — "sbt publish" when none are given. Multi-module builds pass
# their own command:
#   bash "${TOMSHLEY_CICD_TOOLBOX_ROOT}/publish/sbt.sh" sbt +core/publish +plugin/publish
#
# Required env vars (set by adapter YAML):
#   TOMSHLEY_CICD_TAG / _REF_SLUG / _COMMIT_SHA — see platform/publish-policy.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"

source "$TOOLBOX_DIR/platform/publish-policy.sh"
bash "$TOOLBOX_DIR/verify/tag-version-guard.sh"

export TOMSHLEY_CICD_BUILD_REVISION="${CICD_PUBLISH_PINNABLE_TAG}"
[ "$#" -gt 0 ] || set -- sbt publish
log_info "TOMSHLEY_CICD_BUILD_REVISION=${TOMSHLEY_CICD_BUILD_REVISION:-<empty>} — running: $*"
exec "$@"
