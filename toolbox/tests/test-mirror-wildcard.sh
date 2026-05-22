#!/usr/bin/env bash
# Test: mirror/sync.sh wildcard BRANCH_MAP support
# Verifies that develop-* patterns match develop-contrib and push correctly.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_ROOT="$(cd "$SCRIPT_DIR/../scripts/tomshley-cicd-pipelines-toolbox" && pwd)"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
cd "$TMP"

# Set up local "origin" repo with a develop-contrib branch
git init -q --bare origin.git
git init -q --bare mirror.git

git init -q work && cd work
git remote add origin "$TMP/origin.git"
echo "v1" > VERSION
git -c user.email=t@t -c user.name=t add . && git -c user.email=t@t -c user.name=t commit -qm "init"
git checkout -qb develop-contrib
echo "external contribution" >> VERSION
git -c user.email=t@t -c user.name=t commit -qam "contrib"
git push -q origin main develop-contrib 2>/dev/null || git push -q origin develop-contrib

# Run sync.sh with wildcard map
export TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT"
export TOMSHLEY_CICD_MIRROR_URL="$TMP/mirror.git"
export TOMSHLEY_CICD_MIRROR_BRANCH_MAP="develop-*:develop-*"
export TOMSHLEY_CICD_MIRROR_TAGS="false"
export TOMSHLEY_CICD_CURRENT_BRANCH="develop-contrib"
export TOMSHLEY_CICD_IS_TAG="false"
bash "$TOOLBOX_ROOT/mirror/sync.sh" >/dev/null

# Verify mirror has develop-contrib
cd "$TMP/mirror.git"
if ! git show-ref --verify -q refs/heads/develop-contrib; then
  echo "FAIL: develop-contrib not found in mirror"
  exit 1
fi
echo "PASS: wildcard BRANCH_MAP pushed develop-contrib correctly"
