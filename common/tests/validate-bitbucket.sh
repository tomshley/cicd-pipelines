#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Bitbucket-specific structural checks (in-development).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BB_CI="$REPO_ROOT/bitbucket/ci"

echo "=== Bitbucket validation (in-development) ==="

if [ -d "$BB_CI" ]; then
  echo "✅ bitbucket/ci/ directory exists"
else
  echo "⚠️  bitbucket/ci/ directory missing"
fi

echo "PASSED (in-development — warnings only)"
exit 0
