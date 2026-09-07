#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Test: publish policy, verify guards, and the registry-upload recipes
# (generic, cargo, release-assets) against a fake curl that records requests.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_ROOT="$(cd "$SCRIPT_DIR/../scripts/tomshley-cicd-pipelines-toolbox" && pwd)"

PASS_COUNT=0
FAIL_COUNT=0

assert_equal() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $desc"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $desc"
    echo "    Missing:  $needle"
    echo "    In:       $haystack"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "=== test-publish-recipes ==="

# --- syntax: every toolbox script parses ---------------------------------------
find "$TOOLBOX_ROOT" -name '*.sh' -exec bash -n {} +
echo "  PASS: all toolbox scripts parse"
PASS_COUNT=$((PASS_COUNT + 1))

# --- fixtures -------------------------------------------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export REQUEST_LOG="$WORK/requests.log"

# Fake curl: records every invocation, returns an empty JSON array for reads.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/curl" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$REQUEST_LOG"
case " $* " in *" --upload-file "*|*" --request POST "*|*" --request DELETE "*) ;; *) echo '[]' ;; esac
FAKE
chmod +x "$WORK/bin/curl"
export PATH="$WORK/bin:$PATH"

# --- publish policy -------------------------------------------------------------
# Sourced with every option off, the way a GitLab before_script shell runs it;
# the policy must resolve without turning -e/-u/pipefail on behind the caller.
set +eu; set +o pipefail
export TOMSHLEY_CICD_REF_SLUG=feature-x TOMSHLEY_CICD_COMMIT_SHA=abc12345 TOMSHLEY_CICD_TAG=""
source "$TOOLBOX_ROOT/platform/publish-policy.sh" >/dev/null
BRANCH_PINNABLE="$CICD_PUBLISH_PINNABLE_TAG" BRANCH_ROLLING="$CICD_PUBLISH_ROLLING_TAG"
BRANCH_ROLLING_FLAG="$CICD_PUBLISH_ROLLING" BRANCH_VERSION="$CICD_PUBLISH_VERSION" BRANCH_LABELS="$CICD_PUBLISH_LABELS"
export TOMSHLEY_CICD_TAG=v1.2.3
source "$TOOLBOX_ROOT/platform/publish-policy.sh" >/dev/null
LEAKED="$(set -o | grep -E '^(errexit|nounset|pipefail)[[:space:]]+on' || true)"
set -euo pipefail

assert_equal "branch: pinnable tag" "feature-x-abc12345" "$BRANCH_PINNABLE"
assert_equal "branch: rolling tag" "feature-x-latest" "$BRANCH_ROLLING"
assert_equal "branch: rolling enabled" "true" "$BRANCH_ROLLING_FLAG"
assert_equal "branch: version empty" "" "$BRANCH_VERSION"
assert_equal "branch: labels" "feature-x-abc12345 feature-x-latest" "$BRANCH_LABELS"
assert_equal "tag: pinnable tag empty (clean version)" "" "$CICD_PUBLISH_PINNABLE_TAG"
assert_equal "tag: rolling alias" "latest" "$CICD_PUBLISH_ROLLING_TAG"
assert_equal "tag: rolling disabled" "false" "$CICD_PUBLISH_ROLLING"
assert_equal "tag: version" "1.2.3" "$CICD_PUBLISH_VERSION"
assert_equal "tag: labels" "1.2.3" "$CICD_PUBLISH_LABELS"
assert_equal "policy: sourcing leaves shell options untouched" "" "$LEAKED"
assert_equal "policy: branch pipeline without slug fails closed" "failed" \
  "$(TOMSHLEY_CICD_TAG="" TOMSHLEY_CICD_REF_SLUG="" TOMSHLEY_CICD_COMMIT_SHA=abc12345 \
     bash -c "source '$TOOLBOX_ROOT/platform/publish-policy.sh'" >/dev/null 2>&1 && echo passed || echo failed)"
unset TOMSHLEY_CICD_TAG TOMSHLEY_CICD_REF_SLUG TOMSHLEY_CICD_COMMIT_SHA

# --- tag/VERSION guard ----------------------------------------------------------
mkdir -p "$WORK/project" && printf '1.2.3\n' > "$WORK/project/VERSION"
assert_equal "guard: branch pipeline is a no-op" "0" \
  "$(TOMSHLEY_CICD_TAG="" TOMSHLEY_CICD_PROJECT_DIR="$WORK/project" bash "$TOOLBOX_ROOT/verify/tag-version-guard.sh" >/dev/null; echo $?)"
assert_equal "guard: matching tag passes" "0" \
  "$(TOMSHLEY_CICD_TAG=v1.2.3 TOMSHLEY_CICD_PROJECT_DIR="$WORK/project" bash "$TOOLBOX_ROOT/verify/tag-version-guard.sh" >/dev/null; echo $?)"
assert_equal "guard: mismatched tag fails closed" "1" \
  "$(TOMSHLEY_CICD_TAG=v9.9.9 TOMSHLEY_CICD_PROJECT_DIR="$WORK/project" bash "$TOOLBOX_ROOT/verify/tag-version-guard.sh" 2>/dev/null; echo $?)"

# --- webjar pairing -------------------------------------------------------------
cat > "$WORK/pom.xml" <<'POM'
<project>
  <parent><groupId>org.example</groupId><artifactId>parent</artifactId><version>99.0.0</version></parent>
  <groupId>org.webjars</groupId>
  <artifactId>thing</artifactId>
  <version>2.0.0</version>
  <properties><upstreamVersion>2.0.0</upstreamVersion></properties>
  <dependencies><dependency><groupId>x</groupId><artifactId>y</artifactId><version>0.0.1</version></dependency></dependencies>
</project>
POM
assert_equal "webjar: project version wins over parent and dependency versions" "0" \
  "$(TOMSHLEY_CICD_WEBJAR_POM="$WORK/pom.xml" bash "$TOOLBOX_ROOT/verify/webjar-pairing.sh" >/dev/null; echo $?)"
sed -i.bak 's|<upstreamVersion>2.0.0|<upstreamVersion>2.0.1|' "$WORK/pom.xml"
assert_equal "webjar: mismatch fails closed" "1" \
  "$(TOMSHLEY_CICD_WEBJAR_POM="$WORK/pom.xml" bash "$TOOLBOX_ROOT/verify/webjar-pairing.sh" 2>/dev/null; echo $?)"

# --- generic publish ------------------------------------------------------------
export TOMSHLEY_CICD_PUBLISH_AUTH_HEADER='JOB-TOKEN: test-token'
export TOMSHLEY_CICD_GENERIC_UPLOAD_URL_TEMPLATE='https://registry.invalid/projects/1/packages/generic/%s/%s/%s'
printf 'payload' > "$WORK/spec-deadbeef.tar.gz"

: > "$REQUEST_LOG"
(cd "$WORK/project" && TOMSHLEY_CICD_REF_SLUG=develop TOMSHLEY_CICD_COMMIT_SHA=abc12345 TOMSHLEY_CICD_TAG="" \
  TOMSHLEY_CICD_GENERIC_PACKAGE=spec TOMSHLEY_CICD_GENERIC_ARTIFACT="$WORK/spec-deadbeef.tar.gz" \
  bash "$TOOLBOX_ROOT/publish/generic.sh" >/dev/null)
assert_equal "generic branch: two uploads (pinnable + rolling)" "2" "$(grep -c -- '--upload-file' "$REQUEST_LOG")"
assert_contains "generic branch: pinnable URL keeps artifact extension" "$(cat "$REQUEST_LOG")" \
  "generic/spec/develop-abc12345/spec-develop-abc12345.tar.gz"
assert_contains "generic branch: rolling URL" "$(cat "$REQUEST_LOG")" "generic/spec/develop-latest/spec-develop-latest.tar.gz"

: > "$REQUEST_LOG"
(cd "$WORK/project" && TOMSHLEY_CICD_TAG=v1.2.3 TOMSHLEY_CICD_PROJECT_DIR="$WORK/project" \
  TOMSHLEY_CICD_GENERIC_PACKAGE=spec TOMSHLEY_CICD_GENERIC_ARTIFACT="$WORK/spec-deadbeef.tar.gz" \
  bash "$TOOLBOX_ROOT/publish/generic.sh" >/dev/null)
assert_equal "generic tag: single upload" "1" "$(grep -c -- '--upload-file' "$REQUEST_LOG")"
assert_contains "generic tag: clean version URL" "$(cat "$REQUEST_LOG")" "generic/spec/1.2.3/spec-1.2.3.tar.gz"

assert_equal "generic tag: refuses when tag and VERSION differ" "1" \
  "$(cd "$WORK/project" && TOMSHLEY_CICD_TAG=v9.9.9 TOMSHLEY_CICD_PROJECT_DIR="$WORK/project" \
     TOMSHLEY_CICD_GENERIC_PACKAGE=spec TOMSHLEY_CICD_GENERIC_ARTIFACT="$WORK/spec-deadbeef.tar.gz" \
     bash "$TOOLBOX_ROOT/publish/generic.sh" >/dev/null 2>&1; echo $?)"

# --- cargo publish + release assets -----------------------------------------------
export TOMSHLEY_CICD_CARGO_BINARY=tool
export TOMSHLEY_CICD_CARGO_TARGETS="x86_64-unknown-linux-gnu x86_64-pc-windows-gnu"
mkdir -p "$WORK/project/target/x86_64-unknown-linux-gnu/release" "$WORK/project/target/x86_64-pc-windows-gnu/release"
printf 'elf' > "$WORK/project/target/x86_64-unknown-linux-gnu/release/tool"
printf 'pe'  > "$WORK/project/target/x86_64-pc-windows-gnu/release/tool.exe"

: > "$REQUEST_LOG"
(cd "$WORK/project" && TOMSHLEY_CICD_REF_SLUG=develop TOMSHLEY_CICD_COMMIT_SHA=abc12345 TOMSHLEY_CICD_TAG="" \
  bash "$TOOLBOX_ROOT/publish/cargo.sh" >/dev/null)
assert_equal "cargo branch: 2 targets x 2 labels = 4 uploads" "4" "$(grep -c -- '--upload-file' "$REQUEST_LOG")"
assert_contains "cargo: linux platform name" "$(cat "$REQUEST_LOG")" "generic/tool/develop-abc12345/tool-linux-amd64"
assert_contains "cargo: windows keeps .exe" "$(cat "$REQUEST_LOG")" "generic/tool/develop-latest/tool-windows-amd64.exe"

assert_equal "cargo: unsupported target fails closed" "1" \
  "$(cd "$WORK/project" && TOMSHLEY_CICD_REF_SLUG=develop TOMSHLEY_CICD_COMMIT_SHA=abc12345 TOMSHLEY_CICD_TAG="" \
     TOMSHLEY_CICD_CARGO_TARGETS="riscv64gc-unknown-linux-gnu" bash "$TOOLBOX_ROOT/publish/cargo.sh" >/dev/null 2>&1; echo $?)"

printf 'sums\n' > "$WORK/project/SHA256SUMS"
: > "$REQUEST_LOG"
(cd "$WORK/project" && TOMSHLEY_CICD_TAG=v1.2.3 TOMSHLEY_CICD_PROJECT_DIR="$WORK/project" \
  TOMSHLEY_CICD_RELEASE_CHECKSUM_FILE=SHA256SUMS TOMSHLEY_CICD_RELEASE_API_URL='https://registry.invalid/projects/1/releases' \
  bash "$TOOLBOX_ROOT/publish/release-assets.sh" >/dev/null)
assert_equal "release-assets: binaries + checksum uploaded" "3" "$(grep -c -- '--upload-file' "$REQUEST_LOG")"
assert_equal "release-assets: one release created" "1" "$(grep -c -- '--request POST' "$REQUEST_LOG")"
assert_contains "release-assets: link payload names windows binary" "$(grep -- '--request POST' "$REQUEST_LOG")" '"name": "tool-windows-amd64.exe"'
assert_contains "release-assets: link payload names checksum" "$(grep -- '--request POST' "$REQUEST_LOG")" '"name": "SHA256SUMS"'
assert_contains "release-assets: tag_name is the raw tag" "$(grep -- '--request POST' "$REQUEST_LOG")" '"tag_name": "v1.2.3"'

assert_equal "release-assets: refuses branch pipelines" "1" \
  "$(cd "$WORK/project" && TOMSHLEY_CICD_TAG="" TOMSHLEY_CICD_REF_SLUG=develop TOMSHLEY_CICD_COMMIT_SHA=abc12345 \
     bash "$TOOLBOX_ROOT/publish/release-assets.sh" >/dev/null 2>&1; echo $?)"

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
