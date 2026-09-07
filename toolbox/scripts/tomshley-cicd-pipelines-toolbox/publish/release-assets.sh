#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Publish: on a tag pipeline, upload every cross-compiled Cargo binary (and an
# optional checksum file) to the generic package registry under the clean
# version, then create a release whose asset links point at those uploads.
#
# Required env vars (set by consumer):
#   TOMSHLEY_CICD_CARGO_BINARY               — binary name; also the package name
#   TOMSHLEY_CICD_CARGO_TARGETS              — space-separated Rust target triples
#
# Optional env vars (set by consumer):
#   TOMSHLEY_CICD_RELEASE_CHECKSUM_FILE      — checksum file to attach as SHA256SUMS
#
# Required env vars (set by adapter YAML):
#   TOMSHLEY_CICD_TAG                        — release tag (this recipe is tag-only)
#   TOMSHLEY_CICD_GENERIC_UPLOAD_URL_TEMPLATE — printf template receiving
#                                              package, version, filename
#   TOMSHLEY_CICD_PUBLISH_AUTH_HEADER        — complete HTTP auth header
#
# Optional env vars (set by adapter YAML):
#   TOMSHLEY_CICD_RELEASE_API_URL            — release-creation endpoint; unset
#                                              skips the release and only uploads
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/rust-targets.sh"

: "${TOMSHLEY_CICD_CARGO_BINARY:?required — binary name produced by the crate}"
: "${TOMSHLEY_CICD_CARGO_TARGETS:?required — space-separated Rust target triples}"
: "${TOMSHLEY_CICD_TAG:?release assets are published from tag pipelines only}"
: "${TOMSHLEY_CICD_GENERIC_UPLOAD_URL_TEMPLATE:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_PUBLISH_AUTH_HEADER:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_RELEASE_CHECKSUM_FILE:=}"
: "${TOMSHLEY_CICD_RELEASE_API_URL:=}"

source "$TOOLBOX_DIR/platform/publish-policy.sh"
bash "$TOOLBOX_DIR/verify/tag-version-guard.sh"

version="${CICD_PUBLISH_VERSION}"
links=()

upload() { # <file> <filename>
  local url
  # shellcheck disable=SC2059 — the template is a deliberate printf format
  url="$(printf "${TOMSHLEY_CICD_GENERIC_UPLOAD_URL_TEMPLATE}" "${TOMSHLEY_CICD_CARGO_BINARY}" "$version" "$2")"
  log_info "uploading $2 -> ${url}"
  curl --fail --silent --show-error --header "${TOMSHLEY_CICD_PUBLISH_AUTH_HEADER}" --upload-file "$1" "$url"
  links+=("$(NAME="$2" URL="$url" python3 -c 'import json, os; print(json.dumps({"name": os.environ["NAME"], "url": os.environ["URL"]}))')")
}

read -r -a targets <<< "${TOMSHLEY_CICD_CARGO_TARGETS}"
for target in "${targets[@]}"; do
  platform="$(rust_target_platform "$target")" || log_fatal "unsupported Rust target: ${target}"
  binary="$(rust_target_binary "$target" "${TOMSHLEY_CICD_CARGO_BINARY}")"
  file="target/${target}/release/${binary}"
  [ -f "$file" ] || log_fatal "release binary not found: ${file}"
  upload "$file" "${TOMSHLEY_CICD_CARGO_BINARY}-${platform}${binary#"${TOMSHLEY_CICD_CARGO_BINARY}"}"
done

if [ -n "${TOMSHLEY_CICD_RELEASE_CHECKSUM_FILE}" ]; then
  [ -f "${TOMSHLEY_CICD_RELEASE_CHECKSUM_FILE}" ] || log_fatal "checksum file not found: ${TOMSHLEY_CICD_RELEASE_CHECKSUM_FILE}"
  upload "${TOMSHLEY_CICD_RELEASE_CHECKSUM_FILE}" SHA256SUMS
fi

[ -n "${TOMSHLEY_CICD_RELEASE_API_URL}" ] || { log_info "TOMSHLEY_CICD_RELEASE_API_URL unset — assets uploaded, no release created"; exit 0; }

payload="$(printf '%s\n' "${links[@]}" | NAME="${TOMSHLEY_CICD_CARGO_BINARY}" VERSION="$version" TAG="${TOMSHLEY_CICD_TAG}" python3 -c '
import json, os, sys
name, version = os.environ["NAME"], os.environ["VERSION"]
links = [json.loads(line) for line in sys.stdin if line.strip()]
print(json.dumps({
    "name": f"{name} {version}",
    "tag_name": os.environ["TAG"],
    "description": f"{name} release assets",
    "assets": {"links": links},
}))
')"
log_info "creating release ${TOMSHLEY_CICD_TAG} with ${#links[@]} asset links"
curl --fail --silent --show-error --request POST \
  --header "${TOMSHLEY_CICD_PUBLISH_AUTH_HEADER}" --header 'Content-Type: application/json' \
  --data "$payload" "${TOMSHLEY_CICD_RELEASE_API_URL}"
