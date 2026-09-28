#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Test: publish policy, verify guards, and the registry-upload recipes
# (generic, cargo, release-assets) against a fake curl that records requests,
# plus the image-tag preflight guard and its adapter wrappers.
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

assert_lacks() {
  local desc="$1" haystack="$2" pattern="$3"
  if printf '%s' "$haystack" | grep -qE -- "$pattern"; then
    echo "  FAIL: $desc"
    echo "    Found:    $pattern"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
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

# Fake curl: records every invocation plus the contents of each @-file header
# (so tests can prove credentials travel by path), returns an empty JSON array
# for reads, and serves the image-guard fixtures: FAKE_CURL_STATUS and
# FAKE_CURL_BODY answer the guard's --write-out/--output probe, FAKE_CURL_EXIT
# simulates a transport failure, and calls to the token-exchange endpoint get
# FAKE_CURL_EXCHANGE_BODY/FAKE_CURL_EXCHANGE_EXIT instead.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/curl" <<'FAKE'
#!/usr/bin/env bash
set -f
orig_args="$*"
printf '%s\n' "$orig_args" >> "$REQUEST_LOG"
out="" writeout=""
while [ $# -gt 0 ]; do
  case "$1" in
    --output|--write-out|--header)
      [ $# -ge 2 ] || break
      case "$1" in
        --output) out="$2" ;;
        --write-out) writeout="$2" ;;
        --header) case "$2" in
          @*) printf 'header-file:%s\n' "$(cat "${2#@}" 2>/dev/null || echo MISSING)" >> "$REQUEST_LOG" ;;
        esac ;;
      esac
      shift 2 ;;
    *) shift ;;
  esac
done
url=""
for arg in $orig_args; do
  case "$arg" in https://*) url="$arg" ;; esac
done
case "$url" in
  */jwt/auth)
    body="${FAKE_CURL_EXCHANGE_BODY-}"
    [ -n "$body" ] || body='{"token":"fx-exchange-token"}'
    [ -n "$out" ] && printf '%s' "$body" > "$out"
    exit "${FAKE_CURL_EXCHANGE_EXIT:-0}" ;;
esac
if [ "${FAKE_CURL_EXIT:-0}" != "0" ]; then
  [ -n "$writeout" ] && printf '%s' "${FAKE_CURL_STATUS:-000}"
  exit "$FAKE_CURL_EXIT"
fi
if [ -n "$out" ]; then
  body="${FAKE_CURL_BODY-}"
  [ -n "$body" ] || body='{}'
  printf '%s' "$body" > "$out"
fi
if [ -n "$writeout" ]; then
  printf '%s' "${FAKE_CURL_STATUS:-200}"
  exit 0
fi
case " $orig_args " in *" --upload-file "*|*" --request POST "*|*" --request DELETE "*) ;; *) echo '[]' ;; esac
FAKE
chmod +x "$WORK/bin/curl"
export PATH="$WORK/bin:$PATH"

# --- publish policy -------------------------------------------------------------
# Sourced with every option off, the way a GitLab before_script shell runs it;
# the policy must resolve without turning -e/-u/pipefail on behind the caller.
set +eu; set +o pipefail
export TOMSHLEY_CICD_REF_SLUG=feature-x TOMSHLEY_CICD_COMMIT_SHA=abc12345 TOMSHLEY_CICD_TAG=""
# shellcheck disable=SC1091  # resolved toolbox path is intentional
source "$TOOLBOX_ROOT/platform/publish-policy.sh" >/dev/null
BRANCH_PINNABLE="$CICD_PUBLISH_PINNABLE_TAG" BRANCH_ROLLING="$CICD_PUBLISH_ROLLING_TAG"
BRANCH_ROLLING_FLAG="$CICD_PUBLISH_ROLLING" BRANCH_VERSION="$CICD_PUBLISH_VERSION" BRANCH_LABELS="$CICD_PUBLISH_LABELS"
export TOMSHLEY_CICD_TAG=v1.2.3
# shellcheck disable=SC1091  # resolved toolbox path is intentional
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

# --- image tag guard ----------------------------------------------------------
# The helper itself stays CI-independent: no platform-native variables.
leaks="$(grep -oE 'CI_[A-Z_]+|GITLAB_[A-Z_]+|BITBUCKET_[A-Z_]+|GITHUB_[A-Z_]+' \
  "$TOOLBOX_ROOT/verify/image-tag-guard.sh" || true)"
assert_equal "guard: helper reads no platform-native variables" "" "$leaks"

# Protocol coverage drives the real guard against the fake curl above.
# TMPDIR is pinned so scratch-directory cleanup is observable.
mkdir -p "$WORK/guardtmp"
IMG='TOMSHLEY_CICD_REGISTRY_IMAGE=registry.example.invalid/group/image'
ABSENT='{"errors":[{"code":"MANIFEST_UNKNOWN","message":"manifest unknown"}]}'

guard() {
  : > "$REQUEST_LOG"
  env -u TOMSHLEY_CICD_TAG -u TOMSHLEY_CICD_REGISTRY_IMAGE \
      -u TOMSHLEY_CICD_REGISTRY_AUTH_FILE -u CICD_PUBLISH_VERSION \
      -u DOCKER_CONFIG -u DOCKER_AUTH_CONFIG \
      -u FAKE_CURL_STATUS -u FAKE_CURL_BODY -u FAKE_CURL_EXIT \
      -u FAKE_CURL_EXCHANGE_BODY -u FAKE_CURL_EXCHANGE_EXIT \
      TMPDIR="$WORK/guardtmp" "$@" \
    sh "$TOOLBOX_ROOT/verify/image-tag-guard.sh" >/dev/null 2>"$WORK/guard.err"
}

assert_equal "guard: no tag is a no-op even without an image" "0" \
  "$(guard; echo $?)"
assert_equal "guard: the no-op performs no registry request" "" "$(cat "$REQUEST_LOG")"

assert_equal "guard: a tag without an image fails closed" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 && echo pass || echo fail)"
assert_equal "guard: missing image fails before any request" "" "$(cat "$REQUEST_LOG")"

assert_equal "guard: 200 single manifest refuses publication" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" FAKE_CURL_STATUS=200 \
     FAKE_CURL_BODY='{"schemaVersion":2,"mediaType":"application/vnd.oci.image.manifest.v1+json"}' \
     && echo pass || echo fail)"
assert_equal "guard: 200 manifest index refuses publication" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" FAKE_CURL_STATUS=200 \
     FAKE_CURL_BODY='{"schemaVersion":2,"mediaType":"application/vnd.oci.image.index.v1+json","manifests":[]}' \
     && echo pass || echo fail)"

assert_equal "guard: 404 MANIFEST_UNKNOWN permits publication" "0" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" FAKE_CURL_STATUS=404 \
     FAKE_CURL_BODY="$ABSENT"; echo $?)"
assert_equal "guard: 404 NAME_UNKNOWN permits publication" "0" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" FAKE_CURL_STATUS=404 \
     FAKE_CURL_BODY='{"errors":[{"code":"NAME_UNKNOWN","message":"repository name not known"}]}'; echo $?)"
assert_contains "guard: probes the manifest endpoint" "$(cat "$REQUEST_LOG")" \
  "https://registry.example.invalid/v2/group/image/manifests/1.2.3"
assert_contains "guard: sends the manifest Accept types" "$(cat "$REQUEST_LOG")" \
  "Accept: application/vnd.oci.image.index.v1+json"
assert_equal "guard: anonymous probe sends no credential file" "0" \
  "$(grep -c -- '--header @' "$REQUEST_LOG" || true)"
assert_equal "guard: scratch directory is cleaned after a pass" "" \
  "$(ls -A "$WORK/guardtmp")"

assert_equal "guard: a proxy HTML 404 fails closed" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" FAKE_CURL_STATUS=404 \
     FAKE_CURL_BODY='<html><body>Not Found</body></html>' && echo pass || echo fail)"
assert_equal "guard: a plain-text 404 fails closed" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" FAKE_CURL_STATUS=404 \
     FAKE_CURL_BODY='not found' && echo pass || echo fail)"
assert_equal "guard: malformed JSON fails closed" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" FAKE_CURL_STATUS=404 \
     FAKE_CURL_BODY='{"errors":[broken' && echo pass || echo fail)"
assert_equal "guard: mixed absence and other errors fail closed" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" FAKE_CURL_STATUS=404 \
     FAKE_CURL_BODY='{"errors":[{"code":"MANIFEST_UNKNOWN"},{"code":"UNAUTHORIZED"}]}' \
     && echo pass || echo fail)"
assert_equal "guard: an empty errors array fails closed" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" FAKE_CURL_STATUS=404 \
     FAKE_CURL_BODY='{"errors":[]}' && echo pass || echo fail)"
two_docs="$(printf '%s\n%s' "$ABSENT" "$ABSENT")"
assert_equal "guard: multiple JSON documents fail closed" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" FAKE_CURL_STATUS=404 \
     "FAKE_CURL_BODY=$two_docs" && echo pass || echo fail)"

for st in 401 403 429 500 302; do
  assert_equal "guard: HTTP $st fails closed" "fail" \
    "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" "FAKE_CURL_STATUS=$st" \
       FAKE_CURL_BODY='{}' && echo pass || echo fail)"
done

assert_equal "guard: a curl transport failure fails closed" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" FAKE_CURL_EXIT=60 \
     FAKE_CURL_STATUS=000 && echo pass || echo fail)"
assert_contains "guard: the curl exit code is reported" \
  "$(cat "$WORK/guard.err")" "curl exit 60"
assert_equal "guard: scratch directory is cleaned after a failure" "" \
  "$(ls -A "$WORK/guardtmp")"

guard_log="$(cat "$REQUEST_LOG")"
assert_contains "guard: curl ignores user curlrc" "$guard_log" "-q "
assert_contains "guard: curl is restricted to https" "$guard_log" "--proto =https"
assert_contains "guard: connect timeout is bounded" "$guard_log" "--connect-timeout 15"
assert_contains "guard: total request is bounded" "$guard_log" "--max-time 30"
assert_contains "guard: response body is bounded" "$guard_log" "--max-filesize 1048576"
assert_lacks "guard: redirects are never followed" "$guard_log" ' -L |--location'
assert_lacks "guard: TLS verification is never disabled" "$guard_log" ' -k |--insecure'

printf 'Authorization: Bearer fx-caller-token\n' > "$WORK/auth.header"
assert_equal "guard: a caller auth file permits the check" "0" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" \
     TOMSHLEY_CICD_REGISTRY_AUTH_FILE="$WORK/auth.header" \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT"; echo $?)"
assert_equal "guard: the auth file is forwarded by path" "1" \
  "$(grep -c -- "--header @$WORK/auth.header" "$REQUEST_LOG" || true)"
assert_equal "guard: the token never appears in curl arguments" "0" \
  "$(grep -v 'header-file:' "$REQUEST_LOG" | grep -c 'fx-caller-token' || true)"
assert_contains "guard: curl reads the auth file contents" "$(cat "$REQUEST_LOG")" \
  "header-file:Authorization: Bearer fx-caller-token"
assert_lacks "guard: diagnostics never contain the caller token" \
  "$(cat "$WORK/guard.err")" 'fx-caller-token'

assert_equal "guard: a missing auth file fails closed" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" \
     TOMSHLEY_CICD_REGISTRY_AUTH_FILE="$WORK/no-such-header" \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT" && echo pass || echo fail)"
assert_equal "guard: missing auth file fails before any request" "" "$(cat "$REQUEST_LOG")"
: > "$WORK/empty.header"
assert_equal "guard: an empty auth file fails closed" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" \
     TOMSHLEY_CICD_REGISTRY_AUTH_FILE="$WORK/empty.header" \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT" && echo pass || echo fail)"

assert_equal "guard: a version override changes the probed tag" "0" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" CICD_PUBLISH_VERSION=9.9.9-rc.1 \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT"; echo $?)"
assert_contains "guard: the override version lands in the URL" "$(cat "$REQUEST_LOG")" \
  "/manifests/9.9.9-rc.1"

assert_equal "guard: an image without a registry is refused" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 TOMSHLEY_CICD_REGISTRY_IMAGE=alpine \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT" && echo pass || echo fail)"
assert_equal "guard: an uppercase repository is refused" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 TOMSHLEY_CICD_REGISTRY_IMAGE=reg.example.invalid/Group/Image \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT" && echo pass || echo fail)"
assert_equal "guard: an invalid registry is refused" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 TOMSHLEY_CICD_REGISTRY_IMAGE=-bad.example.invalid/group/image \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT" && echo pass || echo fail)"
assert_equal "guard: an invalid tag is refused" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" CICD_PUBLISH_VERSION=-oops \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT" && echo pass || echo fail)"
assert_equal "guard: a multi-line image is refused" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 \
     TOMSHLEY_CICD_REGISTRY_IMAGE="$(printf 'registry.example.invalid/group/image\nother')" \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT" && echo pass || echo fail)"
assert_equal "guard: the refused image never reaches the registry" "" "$(cat "$REQUEST_LOG")"
assert_equal "guard: a multi-line version is refused" "fail" \
  "$(guard TOMSHLEY_CICD_TAG=v1.2.3 "$IMG" \
     CICD_PUBLISH_VERSION="$(printf '1.2.3\nextra')" \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT" && echo pass || echo fail)"
assert_equal "guard: refused inputs never reach the registry" "" "$(cat "$REQUEST_LOG")"

# --- image preflight adapter wrappers -------------------------------------------
# The adapters hold the same contract in platform idioms: extract the complete
# script scalars and execute them against the same fake curl. The GitLab scalar
# is a subshell that ends on its own `)` line, so extraction runs to the end of
# the block scalar rather than stopping at its `fi`.
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

gl_preflight="$WORK/gitlab-image-preflight.sh"
awk '
  $0 == ".tomshley-cicd-image-tag-guard:" { in_job = 1 }
  in_job && /^    - \|$/ { in_script = 1; next }
  in_script && /^      / { sub(/^      /, ""); print; next }
  in_script { exit }
' "$PROJECT_ROOT/adapters/gitlab/ci/adapter.yml" > "$gl_preflight"

bb_preflight="$WORK/bitbucket-image-preflight.sh"
awk '
  /^    - &image-tag-guard \|$/ { in_script = 1; next }
  in_script && /^        / { sub(/^        /, ""); print; next }
  in_script { exit }
' "$PROJECT_ROOT/adapters/bitbucket/ci/adapter.yml" > "$bb_preflight"

run_wrapper() {
  # run_wrapper <script> <env assignments...>
  local script="$1"; shift
  : > "$REQUEST_LOG"
  env -u TOMSHLEY_CICD_TAG -u TOMSHLEY_CICD_REGISTRY_IMAGE \
      -u TOMSHLEY_CICD_REGISTRY_AUTH_FILE -u CICD_PUBLISH_VERSION \
      -u CI_COMMIT_TAG -u CI_REGISTRY -u CI_SERVER_URL -u CI_REGISTRY_USER \
      -u CI_REGISTRY_PASSWORD -u BITBUCKET_TAG \
      -u DOCKER_CONFIG -u DOCKER_AUTH_CONFIG \
      -u FAKE_CURL_STATUS -u FAKE_CURL_BODY -u FAKE_CURL_EXIT \
      -u FAKE_CURL_EXCHANGE_BODY -u FAKE_CURL_EXCHANGE_EXIT \
      TMPDIR="$WORK/guardtmp" "$@" sh "$script" >/dev/null 2>"$WORK/wrapper.err"
}

assert_equal "gitlab preflight: a branch pipeline is a no-op" "0" \
  "$(run_wrapper "$gl_preflight" CI_COMMIT_TAG= \
     TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT"; echo $?)"
assert_equal "gitlab preflight: the no-op performs no request" "" "$(cat "$REQUEST_LOG")"

assert_equal "gitlab preflight: the canonical image variable maps through" "0" \
  "$(run_wrapper "$gl_preflight" CI_COMMIT_TAG=v1.2.3 \
     TOMSHLEY_CICD_REGISTRY_IMAGE=registry.example.invalid/group/image \
     TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT" \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT"; echo $?)"
assert_contains "gitlab preflight: canonical repository is probed" "$(cat "$REQUEST_LOG")" \
  "/v2/group/image/manifests/1.2.3"
assert_equal "gitlab preflight: a foreign registry skips the token exchange" "0" \
  "$(grep -c 'jwt/auth' "$REQUEST_LOG" || true)"

assert_equal "gitlab preflight: a tag without an image fails closed" "fail" \
  "$(run_wrapper "$gl_preflight" CI_COMMIT_TAG=v1.2.3 \
     TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT" && echo pass || echo fail)"
assert_equal "gitlab preflight: a missing image fails before any request" "" "$(cat "$REQUEST_LOG")"

assert_equal "gitlab preflight: same-host registry exchanges the job credentials" "0" \
  "$(run_wrapper "$gl_preflight" CI_COMMIT_TAG=v1.2.3 \
     TOMSHLEY_CICD_REGISTRY_IMAGE=gitlab.example.invalid/group/image \
     CI_REGISTRY=gitlab.example.invalid CI_SERVER_URL=https://gitlab.example.invalid \
     CI_REGISTRY_USER=ci-user CI_REGISTRY_PASSWORD=ci-pass \
     TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT" \
     FAKE_CURL_EXCHANGE_BODY='{"token":"fx-exchange-token"}' \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT"; echo $?)"
gl_log="$(cat "$REQUEST_LOG")"
assert_contains "gitlab preflight: exchange hits the jwt auth endpoint" "$gl_log" \
  "https://gitlab.example.invalid/jwt/auth"
assert_contains "gitlab preflight: exchange names the registry service" "$gl_log" \
  "service=container_registry"
assert_contains "gitlab preflight: exchange requests the pull scope" "$gl_log" \
  "scope=repository:group/image:pull"
assert_contains "gitlab preflight: job credentials travel by header file" "$gl_log" \
  "header-file:Authorization: Basic "
assert_contains "gitlab preflight: the exchanged token reaches the manifest request" "$gl_log" \
  "header-file:Authorization: Bearer fx-exchange-token"
assert_equal "gitlab preflight: the manifest request carries the token by file path" "1" \
  "$(grep '/v2/' "$REQUEST_LOG" | grep -c -- '--header @' || true)"
assert_equal "gitlab preflight: the token never appears in curl arguments" "0" \
  "$(grep -v 'header-file:' "$REQUEST_LOG" | grep -c 'fx-exchange-token' || true)"
assert_equal "gitlab preflight: the exchange scratch directory is cleaned" "" \
  "$(ls -A "$WORK/guardtmp")"
assert_lacks "gitlab preflight: diagnostics never contain the job password" \
  "$(cat "$WORK/wrapper.err")" 'ci-pass'
assert_lacks "gitlab preflight: diagnostics never contain the exchanged token" \
  "$(cat "$WORK/wrapper.err")" 'fx-exchange-token'

assert_equal "gitlab preflight: a failed exchange fails closed" "fail" \
  "$(run_wrapper "$gl_preflight" CI_COMMIT_TAG=v1.2.3 \
     TOMSHLEY_CICD_REGISTRY_IMAGE=gitlab.example.invalid/group/image \
     CI_REGISTRY=gitlab.example.invalid CI_SERVER_URL=https://gitlab.example.invalid \
     CI_REGISTRY_USER=ci-user CI_REGISTRY_PASSWORD=ci-pass \
     TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT" \
     FAKE_CURL_EXCHANGE_EXIT=22 && echo pass || echo fail)"
assert_equal "gitlab preflight: a failed exchange never reaches the manifest" "0" \
  "$(grep -c '/v2/' "$REQUEST_LOG" || true)"
assert_contains "gitlab preflight: the exchange curl exit code is reported" \
  "$(cat "$WORK/wrapper.err")" "curl exit 22"

assert_equal "gitlab preflight: an unusable token fails closed" "fail" \
  "$(run_wrapper "$gl_preflight" CI_COMMIT_TAG=v1.2.3 \
     TOMSHLEY_CICD_REGISTRY_IMAGE=gitlab.example.invalid/group/image \
     CI_REGISTRY=gitlab.example.invalid CI_SERVER_URL=https://gitlab.example.invalid \
     CI_REGISTRY_USER=ci-user CI_REGISTRY_PASSWORD=ci-pass \
     TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT" \
     FAKE_CURL_EXCHANGE_BODY='{"token":"bad token"}' \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT" && echo pass || echo fail)"
assert_equal "gitlab preflight: a bad token never reaches the manifest" "0" \
  "$(grep -c '/v2/' "$REQUEST_LOG" || true)"

printf 'Authorization: Bearer fx-external-token\n' > "$WORK/ext.header"
assert_equal "gitlab preflight: an explicit auth file serves other registries" "0" \
  "$(run_wrapper "$gl_preflight" CI_COMMIT_TAG=v1.2.3 \
     TOMSHLEY_CICD_REGISTRY_IMAGE=registry.example.invalid/group/image \
     TOMSHLEY_CICD_REGISTRY_AUTH_FILE="$WORK/ext.header" \
     TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT" \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT"; echo $?)"
assert_contains "gitlab preflight: the caller auth file reaches the manifest" \
  "$(cat "$REQUEST_LOG")" "header-file:Authorization: Bearer fx-external-token"

assert_equal "gitlab preflight: an explicit auth file wins over the exchange" "0" \
  "$(run_wrapper "$gl_preflight" CI_COMMIT_TAG=v1.2.3 \
     TOMSHLEY_CICD_REGISTRY_IMAGE=gitlab.example.invalid/group/image \
     CI_REGISTRY=gitlab.example.invalid CI_SERVER_URL=https://gitlab.example.invalid \
     CI_REGISTRY_USER=ci-user CI_REGISTRY_PASSWORD=ci-pass \
     TOMSHLEY_CICD_REGISTRY_AUTH_FILE="$WORK/ext.header" \
     TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT" \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT"; echo $?)"
assert_equal "gitlab preflight: no exchange runs when an auth file is given" "0" \
  "$(grep -c 'jwt/auth' "$REQUEST_LOG" || true)"
assert_contains "gitlab preflight: the caller file reaches the manifest on a same-host image" \
  "$(cat "$REQUEST_LOG")" "header-file:Authorization: Bearer fx-external-token"

assert_equal "gitlab preflight: a missing toolbox fails closed" "fail" \
  "$(run_wrapper "$gl_preflight" CI_COMMIT_TAG=v1.2.3 "$IMG" \
     TOMSHLEY_CICD_TOOLBOX_ROOT="$WORK/no-toolbox" \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT" && echo pass || echo fail)"

assert_equal "bitbucket anchor: a branch pipeline is a no-op" "0" \
  "$(run_wrapper "$bb_preflight" BITBUCKET_TAG= \
     TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT"; echo $?)"
assert_equal "bitbucket anchor: the no-op performs no request" "" "$(cat "$REQUEST_LOG")"
assert_equal "bitbucket anchor: the tag probes the same version as gitlab" "0" \
  "$(run_wrapper "$bb_preflight" BITBUCKET_TAG=v1.2.3 "$IMG" \
     TOMSHLEY_CICD_TOOLBOX_ROOT="$TOOLBOX_ROOT" \
     FAKE_CURL_STATUS=404 FAKE_CURL_BODY="$ABSENT"; echo $?)"
assert_contains "bitbucket anchor: probes the tag-derived version" "$(cat "$REQUEST_LOG")" \
  "/manifests/1.2.3"

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
