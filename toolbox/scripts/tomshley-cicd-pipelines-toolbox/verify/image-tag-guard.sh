#!/bin/sh
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Read-only OCI manifest preflight. Registry-side immutability prevents races.
# The caller supplies registry authentication; this check does not log in.
# Requires curl and jq. No Docker daemon or CI platform is required.
set -eu
[ -n "${TOMSHLEY_CICD_TAG:-}" ] || exit 0
: "${TOMSHLEY_CICD_REGISTRY_IMAGE:?required for a release image check}"

ref="${TOMSHLEY_CICD_REGISTRY_IMAGE}"
version="${CICD_PUBLISH_VERSION:-${TOMSHLEY_CICD_TAG#v}}"
registry="${ref%%/*}"
repository="${ref#*/}"
fail() { echo "ERROR: $* — refusing publication" >&2; exit 1; }
nl='
'
matches() { case "$1" in *"$nl"*) return 1 ;; esac; printf '%s\n' "$1" | LC_ALL=C grep -Eq "$2"; }

# Explicit registry/repository inputs avoid guessing Docker Hub namespaces.
matches "$registry" '^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?(:[0-9]+)?$' \
  || fail "invalid registry"
[ "$repository" != "$ref" ] || fail "image must include its registry and repository"
matches "$repository" '^[a-z0-9]+(([._]|__|-+)[a-z0-9]+)*(/[a-z0-9]+(([._]|__|-+)[a-z0-9]+)*)*$' \
  || fail "invalid image repository"
matches "$version" '^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$' \
  || fail "invalid image tag"

umask 077
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
set -- --header 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json'
if [ -n "${TOMSHLEY_CICD_REGISTRY_AUTH_FILE:-}" ]; then
  [ -s "$TOMSHLEY_CICD_REGISTRY_AUTH_FILE" ] || fail "registry authentication file is missing or empty"
  set -- "$@" --header "@${TOMSHLEY_CICD_REGISTRY_AUTH_FILE}"
fi

# -q ignores curlrc; redirects are not followed and TLS is always verified.
# Credentials travel through a file, never command arguments or diagnostics.
rc=0
status="$(curl -q --silent --proto '=https' \
  --connect-timeout 15 --max-time 30 --max-filesize 1048576 \
  --output "$work/body" --write-out '%{http_code}' "$@" \
  "https://${registry}/v2/${repository}/manifests/${version}" 2>/dev/null)" \
  || rc=$?
[ "$rc" -eq 0 ] || fail "registry request failed (curl exit ${rc})"

case "$status" in
  200) fail "image tag already exists; publish a new version" ;;
  404)
    # A proxy's generic 404 is not proof of an absent manifest. Require the
    # registry's structured absence codes, with no mixed or unknown errors.
    jq -e -s 'length == 1 and (.[0] |
      (.errors | type == "array" and length > 0) and
      all(.errors[]; .code == "MANIFEST_UNKNOWN" or .code == "NAME_UNKNOWN"))' \
      "$work/body" >/dev/null 2>&1 \
      || fail "registry did not confirm that the manifest is absent"
    ;;
  *) fail "registry state is unknown (HTTP ${status})" ;;
esac
echo "Image tag ${ref}:${version} is absent; publication may proceed."
