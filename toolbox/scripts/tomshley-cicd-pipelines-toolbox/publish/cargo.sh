#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Publish: upload every cross-compiled Cargo binary (built by
# build/cargo-zigbuild.sh) to a generic package registry as
# <binary>-<platform>[.exe], under every label the artifact policy selects.
#
# Required env vars (set by consumer):
#   TOMSHLEY_CICD_CARGO_BINARY               — binary name; also the package name
#   TOMSHLEY_CICD_CARGO_TARGETS              — space-separated Rust target triples
#
# Required env vars (set by adapter YAML):
#   TOMSHLEY_CICD_GENERIC_UPLOAD_URL_TEMPLATE — printf template receiving
#                                              package, version, filename
#   TOMSHLEY_CICD_PUBLISH_AUTH_HEADER        — complete HTTP auth header
#   TOMSHLEY_CICD_TAG / _REF_SLUG / _COMMIT_SHA — see platform/publish-policy.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/rust-targets.sh"

: "${TOMSHLEY_CICD_CARGO_BINARY:?required — binary name produced by the crate}"
: "${TOMSHLEY_CICD_CARGO_TARGETS:?required — space-separated Rust target triples}"
: "${TOMSHLEY_CICD_GENERIC_UPLOAD_URL_TEMPLATE:?required — set by adapter YAML}"
: "${TOMSHLEY_CICD_PUBLISH_AUTH_HEADER:?required — set by adapter YAML}"

source "$TOOLBOX_DIR/platform/publish-policy.sh"
bash "$TOOLBOX_DIR/verify/tag-version-guard.sh"

read -r -a targets <<< "${TOMSHLEY_CICD_CARGO_TARGETS}"
for target in "${targets[@]}"; do
  platform="$(rust_target_platform "$target")" || log_fatal "unsupported Rust target: ${target}"
  binary="$(rust_target_binary "$target" "${TOMSHLEY_CICD_CARGO_BINARY}")"
  file="target/${target}/release/${binary}"
  [ -f "$file" ] || log_fatal "release binary not found: ${file}"
  filename="${TOMSHLEY_CICD_CARGO_BINARY}-${platform}${binary#"${TOMSHLEY_CICD_CARGO_BINARY}"}"
  for label in ${CICD_PUBLISH_LABELS}; do
    # shellcheck disable=SC2059 — the template is a deliberate printf format
    url="$(printf "${TOMSHLEY_CICD_GENERIC_UPLOAD_URL_TEMPLATE}" "${TOMSHLEY_CICD_CARGO_BINARY}" "$label" "$filename")"
    log_info "uploading ${filename} -> ${url}"
    curl --fail --silent --show-error --header "${TOMSHLEY_CICD_PUBLISH_AUTH_HEADER}" \
      --upload-file "$file" "$url"
  done
done
