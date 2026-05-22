#!/usr/bin/env bash
# Test: mirror/sync.sh refuses unsupported wildcard rename mappings.
# Identity wildcards (foo-*:foo-*) are supported; rename wildcards
# (foo-*:bar-*) and asymmetric wildcard configurations are not, and must
# be skipped with a warning rather than silently pushed to the wrong ref.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_ROOT="$(cd "$SCRIPT_DIR/../scripts/tomshley-cicd-pipelines-toolbox" && pwd)"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
cd "$TMP"

git init -q --bare origin.git
git init -q --bare mirror.git

git init -q work && cd work
git remote add origin "$TMP/origin.git"
echo "v1" > VERSION
git -c user.email=t@t -c user.name=t add . && git -c user.email=t@t -c user.name=t commit -qm "init"
git checkout -qb develop-1.0
echo "rc" >> VERSION
git -c user.email=t@t -c user.name=t commit -qam "rc"
git push -q origin develop-1.0 2>/dev/null || true

export TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT"
export TOMSHLEY_CICD_MIRROR_URL="$TMP/mirror.git"
export TOMSHLEY_CICD_MIRROR_TAGS="false"
export TOMSHLEY_CICD_CURRENT_BRANCH="develop-1.0"
export TOMSHLEY_CICD_IS_TAG="false"

# Case 1: wildcard rename — must be skipped
export TOMSHLEY_CICD_MIRROR_BRANCH_MAP="develop-*:release-*"
SYNC_LOG=$(mktemp)
bash "$TOOLBOX_ROOT/mirror/sync.sh" >"$SYNC_LOG" 2>&1
if git --git-dir="$TMP/mirror.git" show-ref --verify -q refs/heads/develop-1.0; then
  echo "FAIL: wildcard rename pushed to wrong branch (develop-1.0 should not exist on mirror)"
  cat "$SYNC_LOG"
  exit 1
fi
if git --git-dir="$TMP/mirror.git" show-ref --verify -q refs/heads/release-1.0; then
  echo "FAIL: wildcard rename produced unexpected branch (release-1.0)"
  cat "$SYNC_LOG"
  exit 1
fi
if ! grep -q "Skipping unsupported wildcard mapping" "$SYNC_LOG"; then
  echo "FAIL: expected wildcard rename to log a skip warning"
  cat "$SYNC_LOG"
  exit 1
fi
echo "PASS: wildcard rename 'develop-*:release-*' was refused with a warning"

# Case 2: asymmetric mapping (literal src, wildcard dst) — must be skipped.
# Without the guard, the previous wildcard logic would fall back to identity
# and silently push develop-1.0 → develop-1.0 on the mirror.
export TOMSHLEY_CICD_MIRROR_BRANCH_MAP="develop-1.0:release-*"
bash "$TOOLBOX_ROOT/mirror/sync.sh" >"$SYNC_LOG" 2>&1
if git --git-dir="$TMP/mirror.git" show-ref --verify -q refs/heads/develop-1.0; then
  echo "FAIL: asymmetric wildcard silently pushed develop-1.0 to mirror"
  cat "$SYNC_LOG"
  exit 1
fi
if ! grep -q "Skipping unsupported wildcard mapping" "$SYNC_LOG"; then
  echo "FAIL: expected asymmetric wildcard to log a skip warning"
  cat "$SYNC_LOG"
  exit 1
fi
echo "PASS: asymmetric mapping 'develop-1.0:release-*' was refused with a warning"
