#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Test: package retention keeps release and rolling versions, deletes old
# pinnable builds, and follows pagination across a two-page listing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBOX_ROOT="$(cd "$SCRIPT_DIR/../scripts/tomshley-cicd-pipelines-toolbox" && pwd)"

echo "=== test-retention ==="

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export RETENTION_DELETE_LOG="$WORK/deletes.log"
: > "$RETENTION_DELETE_LOG"

# Fake curl: DELETEs are logged; listings are paginated — page 1 is a full
# page (per_page=100: four fixtures plus release-version filler), page 2 is a
# short final page. Versions cover every shape the recipes produce:
# generic/cargo labels, npm prereleases, PEP 440 local versions.
cat > "$WORK/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
case " $* " in
  *" DELETE "*) printf '%s\n' "$*" >> "${RETENTION_DELETE_LOG}"; exit 0 ;;
esac
url="${*: -1}"
case "$url" in
  *'&page=1')
    printf '['
    printf '%s,' \
      '{"id":10,"version":"develop-abc12345","created_at":"2020-01-01T00:00:00Z"}' \
      '{"id":11,"version":"0.1.0.dev0+a.develop.abc12345","created_at":"2020-01-01T00:00:00Z"}' \
      '{"id":12,"version":"develop-latest","created_at":"2020-01-01T00:00:00Z"}' \
      '{"id":13,"version":"1.0.0","created_at":"2020-01-01T00:00:00Z"}'
    for n in $(seq 1 95); do printf '{"id":%s,"version":"9.0.%s","created_at":"2020-01-01T00:00:00Z"},' "$((100 + n))" "$n"; done
    printf '{"id":199,"version":"9.9.9","created_at":"2020-01-01T00:00:00Z"}]\n'
  ;;
  *'&page=2') cat <<'JSON'
[
  {"id":20,"version":"0.1.0-develop.abc12345","created_at":"2020-01-01T00:00:00Z"},
  {"id":21,"version":"0.1.0.dev0+z.develop.latest","created_at":"2020-01-01T00:00:00Z"},
  {"id":22,"version":"feature-new-thing-deadbeef","created_at":"2999-01-01T00:00:00Z"}
]
JSON
  ;;
  *) echo '[]' ;;
esac
FAKE_CURL
chmod +x "$WORK/curl"

PATH="$WORK:$PATH" TOMSHLEY_CICD_RETENTION_DAYS=30 \
  TOMSHLEY_CICD_PACKAGES_API_URL=https://registry.invalid/projects/1/packages \
  TOMSHLEY_CICD_PUBLISH_AUTH_HEADER='JOB-TOKEN: test-token' \
  bash "$TOOLBOX_ROOT/retention/package-retention.sh" > "$WORK/output.log"

FAIL=0
expect_deleted() {
  if grep -q "/packages/$1\$" "$RETENTION_DELETE_LOG"; then echo "  PASS: deleted $1 ($2)"; else echo "  FAIL: did not delete $1 ($2)"; FAIL=1; fi
}
expect_kept() {
  if ! grep -q "/packages/$1\$" "$RETENTION_DELETE_LOG" && grep -q "KEEP $2 $1 " "$WORK/output.log"; then
    echo "  PASS: kept $1 ($2)"
  else
    echo "  FAIL: expected to keep $1 as $2"; FAIL=1
  fi
}

expect_deleted 10 "generic pinnable label"
expect_deleted 11 "PEP 440 pinnable local version"
expect_deleted 20 "npm pinnable prerelease (page 2)"
expect_kept 12 rolling
expect_kept 13 release
expect_kept 21 rolling
expect_kept 22 recent

DELETES="$(wc -l < "$RETENTION_DELETE_LOG" | tr -d ' ')"
if [ "$DELETES" = 3 ]; then echo "  PASS: exactly 3 deletions"; else echo "  FAIL: expected 3 deletions, got $DELETES"; FAIL=1; fi

exit "$FAIL"
