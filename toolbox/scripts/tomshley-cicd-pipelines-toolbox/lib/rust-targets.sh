#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Rust target triple ↔ release platform naming, shared by the Cargo build
# and publish recipes so every artifact carries the same platform suffix.
# Source this file; do not execute directly.

# rust_target_platform <target-triple> — prints the release platform slug.
# Returns 1 for a triple that has no house platform name.
rust_target_platform() {
  case "$1" in
    x86_64-unknown-linux-gnu)   echo linux-amd64 ;;
    aarch64-unknown-linux-gnu)  echo linux-aarch64 ;;
    x86_64-unknown-linux-musl)  echo linux-amd64-musl ;;
    aarch64-unknown-linux-musl) echo linux-aarch64-musl ;;
    x86_64-apple-darwin)        echo darwin-amd64 ;;
    aarch64-apple-darwin)       echo darwin-aarch64 ;;
    x86_64-pc-windows-gnu)      echo windows-amd64 ;;
    *) return 1 ;;
  esac
}

# rust_target_binary <target-triple> <binary-name> — prints the binary file
# name cargo emits for the triple (".exe" on Windows targets).
rust_target_binary() {
  case "$1" in
    *-windows-*) echo "$2.exe" ;;
    *)           echo "$2" ;;
  esac
}
