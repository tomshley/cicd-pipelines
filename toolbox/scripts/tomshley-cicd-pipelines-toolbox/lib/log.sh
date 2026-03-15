#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Logging helpers for cicd-pipelines toolbox scripts.
# Source this file; do not execute directly.

log_info()  { echo "INFO:  $*"; }
log_warn()  { echo "WARN:  $*" >&2; }
log_error() { echo "ERROR: $*" >&2; }
log_fatal() { echo "FATAL: $*" >&2; exit 1; }
