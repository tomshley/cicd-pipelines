#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Package-registry helpers over the generic package collection API
# (a list endpoint returning JSON objects with id, name, version, created_at;
# a DELETE endpoint at <collection>/<id>). Requires curl and python3.
# Source this file; do not execute directly.
#
# Required environment variables (set by adapter YAML):
#   TOMSHLEY_CICD_PACKAGES_API_URL    — package collection URL
#   TOMSHLEY_CICD_PUBLISH_AUTH_HEADER — complete HTTP auth header

# packages_list [query] — prints every package as one JSON array, following
# per_page/page pagination until the registry returns a short or empty page.
# <query> is an optional "?key=value" filter string.
packages_list() {
  local query="${1:-}" page=1 pages separator='?' per_page=100
  pages="$(mktemp -d)"
  case "$query" in *\?*) separator='&' ;; esac
  while :; do
    curl --fail --silent --show-error \
      --header "${TOMSHLEY_CICD_PUBLISH_AUTH_HEADER}" \
      "${TOMSHLEY_CICD_PACKAGES_API_URL}${query}${separator}per_page=${per_page}&page=${page}" \
      > "${pages}/${page}.json"
    # A page shorter than per_page is the last one; this also ends the loop
    # against a registry that ignores the page parameter.
    python3 -c 'import json, sys; sys.exit(0 if len(json.load(open(sys.argv[1]))) >= int(sys.argv[2]) else 1)' \
      "${pages}/${page}.json" "$per_page" || break
    page=$((page + 1))
  done
  python3 -c '
import json, sys
packages = []
for path in sys.argv[1:]:
    packages.extend(json.load(open(path)))
print(json.dumps(packages))
' "${pages}"/*.json
  rm -rf "${pages}"
}

# packages_delete <id> — deletes a single package by id.
packages_delete() {
  curl --fail --silent --show-error --request DELETE \
    --header "${TOMSHLEY_CICD_PUBLISH_AUTH_HEADER}" \
    "${TOMSHLEY_CICD_PACKAGES_API_URL}/$1"
}

# packages_delete_version <type> <name> <version> — deletes every package of
# the given type whose name and version match exactly. Used before
# re-publishing a rolling version to registries that refuse duplicates.
packages_delete_version() {
  local type="$1" name="$2" version="$3" id
  packages_list "?package_type=${type}&package_name=${name}" \
    | PKG_NAME="$name" PKG_VERSION="$version" python3 -c '
import json, os, sys
for package in json.load(sys.stdin):
    if package.get("name") == os.environ["PKG_NAME"] and package.get("version") == os.environ["PKG_VERSION"]:
        print(package["id"])
' | while read -r id; do
        [ -n "$id" ] || continue
        echo "INFO:  deleting existing ${type} package ${name} ${version} (id ${id})"
        packages_delete "$id"
      done
}
