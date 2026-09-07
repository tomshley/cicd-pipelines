#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Build: cross-compile a Cargo binary for every configured target with
# cargo-zigbuild, then optionally lay the binaries out as native resources
# with a checksum file and manifest.
#
# Runs inside a runner image that already provides rustup, cargo-zigbuild,
# and zig (cicd-runner-sbtrustdockertofu). Toolchain versions are an image
# concern and are never installed here.
#
# Required env vars (set by consumer):
#   TOMSHLEY_CICD_CARGO_TARGETS       — space-separated Rust target triples
#   TOMSHLEY_CICD_CARGO_BINARY        — binary name produced by the crate
#
# Optional env vars (set by consumer):
#   TOMSHLEY_CICD_CARGO_NATIVE_ROOT   — directory receiving <platform>/<binary>
#                                       copies plus manifest.json (unset = skip)
#   TOMSHLEY_CICD_CARGO_CHECKSUM_FILE — sha256sum output path (default: SHA256SUMS)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"
source "$TOOLBOX_DIR/lib/rust-targets.sh"

: "${TOMSHLEY_CICD_CARGO_TARGETS:?required — space-separated Rust target triples}"
: "${TOMSHLEY_CICD_CARGO_BINARY:?required — binary name produced by the crate}"
: "${TOMSHLEY_CICD_CARGO_NATIVE_ROOT:=}"
: "${TOMSHLEY_CICD_CARGO_CHECKSUM_FILE:=SHA256SUMS}"

read -r -a targets <<< "${TOMSHLEY_CICD_CARGO_TARGETS}"
for target in "${targets[@]}"; do
  rust_target_platform "$target" >/dev/null || log_fatal "unsupported Rust target: ${target}"
done

rustup target add "${targets[@]}"
for target in "${targets[@]}"; do
  log_info "cargo zigbuild --release --target ${target}"
  cargo zigbuild --release --target "$target"
done

[ -n "${TOMSHLEY_CICD_CARGO_NATIVE_ROOT}" ] || exit 0

root="${TOMSHLEY_CICD_CARGO_NATIVE_ROOT}"
for target in "${targets[@]}"; do
  platform="$(rust_target_platform "$target")"
  binary="$(rust_target_binary "$target" "${TOMSHLEY_CICD_CARGO_BINARY}")"
  mkdir -p "${root}/${platform}"
  cp "target/${target}/release/${binary}" "${root}/${platform}/${binary}"
done
find "$root" -mindepth 2 -maxdepth 2 -type f -name "${TOMSHLEY_CICD_CARGO_BINARY}*" -print0 \
  | sort -z | xargs -0 sha256sum > "${TOMSHLEY_CICD_CARGO_CHECKSUM_FILE}"
NATIVE_ROOT="$root" python3 - <<'PY'
import hashlib, json, os
from pathlib import Path
root = Path(os.environ["NATIVE_ROOT"])
manifest = {
    platform.name: hashlib.sha256(binary.read_bytes()).hexdigest()
    for platform in sorted(p for p in root.iterdir() if p.is_dir())
    for binary in sorted(platform.iterdir())
}
(root / "manifest.json").write_text(json.dumps(manifest, sort_keys=True) + "\n")
PY
log_info "native resources written to ${root} (${#targets[@]} targets)"
