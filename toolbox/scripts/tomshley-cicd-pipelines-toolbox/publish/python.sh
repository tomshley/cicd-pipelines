#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Publish: a Python distribution to a PyPI-compatible package registry.
#
# The project's build composes its own version from the channel the toolbox
# announces: TOMSHLEY_CICD_BUILD_CHANNEL is "tag", "pinnable", or "rolling"
# and TOMSHLEY_CICD_BUILD_REVISION carries the matching artifact tag (empty on
# tags). Tag pipelines publish once; branch pipelines publish the pinnable
# build, then the rolling build after deleting the previous rolling upload of
# the same version (PyPI registries refuse duplicate versions).
#
# Required env vars (set by consumer):
#   TOMSHLEY_CICD_PYPI_PACKAGE         — distribution name as the registry lists it
#
# Required env vars (set by adapter YAML):
#   TOMSHLEY_CICD_PYPI_REPOSITORY_URL  — upload endpoint
#   TOMSHLEY_CICD_PACKAGE_USER         — registry username
#   TOMSHLEY_CICD_PACKAGE_TOKEN        — registry credential
#   TOMSHLEY_CICD_PACKAGES_API_URL     — package collection URL (rolling cleanup)
#   TOMSHLEY_CICD_PUBLISH_AUTH_HEADER  — complete HTTP auth header (rolling cleanup)
#   TOMSHLEY_CICD_TAG / _REF_SLUG / _COMMIT_SHA — see platform/publish-policy.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/tools.sh"
source "$TOOLBOX_DIR/lib/packages.sh"

: "${TOMSHLEY_CICD_PYPI_PACKAGE:?required — distribution name}"
: "${TOMSHLEY_CICD_PYPI_REPOSITORY_URL:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_PACKAGE_USER:?required — registry username}"
: "${TOMSHLEY_CICD_PACKAGE_TOKEN:?required — registry credential}"
: "${TOMSHLEY_CICD_PACKAGES_API_URL:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_PUBLISH_AUTH_HEADER:?required — set by adapter YAML}"

tools_require python3 python3
python3 -m pip --version >/dev/null 2>&1 || tools_require pip3 py3-pip
source "$TOOLBOX_DIR/platform/publish-policy.sh"
bash "$TOOLBOX_DIR/verify/tag-version-guard.sh"

python3 -m pip install --quiet --no-cache-dir build twine

# Credentials travel through twine's environment, never its argument list.
export TWINE_REPOSITORY_URL="${TOMSHLEY_CICD_PYPI_REPOSITORY_URL}"
export TWINE_USERNAME="${TOMSHLEY_CICD_PACKAGE_USER}"
export TWINE_PASSWORD="${TOMSHLEY_CICD_PACKAGE_TOKEN}"

# build_distribution <channel> <revision> — builds into dist/ and prints the
# version the build tool assigned (read back from the wheel file name).
build_distribution() {
  rm -rf dist build ./*.egg-info src/*.egg-info
  TOMSHLEY_CICD_BUILD_CHANNEL="$1" TOMSHLEY_CICD_BUILD_REVISION="$2" python3 -m build >&2
  python3 -c '
import pathlib, sys
wheels = sorted(pathlib.Path("dist").glob("*.whl"))
if not wheels:
    sys.exit("no wheel produced in dist/")
print(wheels[0].name.split("-")[1])
'
}

upload_distribution() { # <channel> <revision>
  local version
  version="$(build_distribution "$1" "$2")"
  if [ "$1" = rolling ]; then
    packages_delete_version pypi "${TOMSHLEY_CICD_PYPI_PACKAGE}" "$version"
  fi
  log_info "uploading ${TOMSHLEY_CICD_PYPI_PACKAGE} ${version} (${1})"
  python3 -m twine upload dist/*
}

if [ -n "${TOMSHLEY_CICD_TAG}" ]; then
  upload_distribution tag ""
else
  upload_distribution pinnable "${CICD_PUBLISH_PINNABLE_TAG}"
  upload_distribution rolling "${CICD_PUBLISH_ROLLING_TAG}"
fi
