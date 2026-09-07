#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Publish: an npm package to a package registry.
#
# Tag pipelines publish package.json's version unchanged (it must equal the
# tag). Branch pipelines publish ONE pinnable prerelease version,
# <base>-<ref-slug>.<sha>, and point the rolling dist-tag <ref-slug>-latest at
# it — npm's rolling mechanism is the dist-tag, never a second version, since
# registries refuse to overwrite a published version.
#
# Required env vars (set by adapter YAML):
#   TOMSHLEY_CICD_NPM_REGISTRY         — registry URL to publish to
#   TOMSHLEY_CICD_NPM_AUTH_KEY         — .npmrc auth key (registry path without
#                                        the leading scheme, e.g. //host/path/)
#   TOMSHLEY_CICD_PACKAGE_TOKEN        — registry credential
#   TOMSHLEY_CICD_TAG / _REF_SLUG / _COMMIT_SHA — see platform/publish-policy.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/tools.sh"

: "${TOMSHLEY_CICD_NPM_REGISTRY:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_NPM_AUTH_KEY:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_PACKAGE_TOKEN:?required — registry credential}"

tools_require node nodejs npm
source "$TOOLBOX_DIR/platform/publish-policy.sh"
bash "$TOOLBOX_DIR/verify/tag-version-guard.sh"

npm config set "${TOMSHLEY_CICD_NPM_AUTH_KEY}:_authToken" "${TOMSHLEY_CICD_PACKAGE_TOKEN}"
base_version="$(node -p "require('./package.json').version")"

if [ -n "${TOMSHLEY_CICD_TAG}" ]; then
  [ "$base_version" = "${CICD_PUBLISH_VERSION}" ] \
    || log_fatal "tag/package version mismatch: tag=${CICD_PUBLISH_VERSION} package.json=${base_version}"
  log_info "publishing ${base_version}"
  npm publish --registry "${TOMSHLEY_CICD_NPM_REGISTRY}"
else
  version="${base_version}-${CICD_PUBLISH_PINNABLE_TAG//-/.}"
  npm pkg set version="${version}"
  log_info "publishing ${version} with dist-tag ${CICD_PUBLISH_ROLLING_TAG}"
  npm publish --tag "${CICD_PUBLISH_ROLLING_TAG}" --registry "${TOMSHLEY_CICD_NPM_REGISTRY}"
fi
