#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Master conformance runner.
# Reads platform-status.yml and required-implementations.yml,
# checks each active/in-development platform against the specs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPECS_DIR="$REPO_ROOT/common/specs"

ERRORS=0
WARNINGS=0

log_error() { echo "❌ ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { echo "⚠️  WARN:  $1"; WARNINGS=$((WARNINGS + 1)); }
log_ok()    { echo "✅ OK:    $1"; }

# Parse platform-status.yml (simple grep-based, no yq dependency)
get_platform_status() {
  local platform="$1"
  grep -A1 "^  ${platform}:" "$SPECS_DIR/platform-status.yml" | grep 'status:' | awk '{print $2}' || echo "roadmap"
}

# Check if a template file exists for a platform
check_template() {
  local platform="$1" name="$2" status="$3"
  local file="$REPO_ROOT/${platform}/ci/.${name}.yml"
  if [ -f "$file" ]; then
    log_ok "$platform/ci/.${name}.yml exists"
    return 0
  else
    if [ "$status" = "active" ]; then
      log_error "$platform/ci/.${name}.yml MISSING (platform is active)"
    else
      log_warn "$platform/ci/.${name}.yml missing (platform is $status)"
    fi
    return 1
  fi
}

# Check required variables in a template
check_variables() {
  local file="$1" status="$2"
  shift 2
  for var in "$@"; do
    if grep -q "$var" "$file" 2>/dev/null; then
      log_ok "  $var found in $(basename "$file")"
    else
      if [ "$status" = "active" ]; then
        log_error "  $var NOT FOUND in $(basename "$file")"
      else
        log_warn "  $var not found in $(basename "$file")"
      fi
    fi
  done
}

# Check required hidden jobs in a template
check_jobs() {
  local file="$1" status="$2"
  shift 2
  for job in "$@"; do
    if grep -q "^${job}:" "$file" 2>/dev/null; then
      log_ok "  $job defined in $(basename "$file")"
    else
      if [ "$status" = "active" ]; then
        log_error "  $job NOT DEFINED in $(basename "$file")"
      else
        log_warn "  $job not defined in $(basename "$file")"
      fi
    fi
  done
}

echo "=== CI/CD Pipelines Conformance Test ==="
echo ""

# ── Pinned Versions Drift Check ──────────────────────────────────────────────
PINNED_FILE="$REPO_ROOT/PINNED_PIPELINE_VERSIONS"
if [ -f "$PINNED_FILE" ]; then
  echo "--- pinned-versions drift check ---"
  # Source the pinned file to get expected values
  source "$PINNED_FILE"

  # Check BASE_CONTAINERS_UPSTREAM_TAG in YAML files
  for yaml_file in \
    "$REPO_ROOT/.gitlab-ci.yml" \
    "$REPO_ROOT/gitlab/ci/.docker-runtime.yml" \
    "$REPO_ROOT/gitlab/ci/.sbt-docker-publish.yml"; do
    if [ -f "$yaml_file" ]; then
      yaml_line=$(grep 'BASE_CONTAINERS_UPSTREAM_TAG' "$yaml_file" | grep -v '\${' | head -1 || true)
      yaml_val=$(echo "$yaml_line" | awk -F: '{print $NF}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
      if [ -n "$yaml_line" ] && [ -z "$yaml_val" ]; then
        log_warn "BASE_CONTAINERS_UPSTREAM_TAG in $(basename "$yaml_file") has non-semver value; skipping drift check"
      elif [ -n "$yaml_val" ] && [ "$yaml_val" != "$BASE_CONTAINERS_UPSTREAM_TAG" ]; then
        log_error "BASE_CONTAINERS_UPSTREAM_TAG in $(basename "$yaml_file") is '$yaml_val' but PINNED_PIPELINE_VERSIONS says '$BASE_CONTAINERS_UPSTREAM_TAG'"
      elif [ -n "$yaml_val" ]; then
        log_ok "BASE_CONTAINERS_UPSTREAM_TAG in $(basename "$yaml_file") matches pinned ($yaml_val)"
      fi
    fi
  done

  # Check CICD_PIPELINES_RUNNER_TAG in consumer templates
  for yaml_file in \
    "$REPO_ROOT/gitlab/ci/.sbt-runtime.yml" \
    "$REPO_ROOT/gitlab/ci/.sbt-rust-runtime.yml" \
    "$REPO_ROOT/gitlab/ci/.terraform-runtime.yml"; do
    if [ -f "$yaml_file" ]; then
      yaml_line=$(grep 'CICD_PIPELINES_RUNNER_TAG' "$yaml_file" | grep -v '\${' | head -1 || true)
      yaml_val=$(echo "$yaml_line" | awk -F: '{print $NF}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
      if [ -n "$yaml_line" ] && [ -z "$yaml_val" ]; then
        log_warn "CICD_PIPELINES_RUNNER_TAG in $(basename "$yaml_file") has non-semver value; skipping drift check"
      elif [ -n "$yaml_val" ] && [ "$yaml_val" != "$CICD_PIPELINES_RUNNER_TAG" ]; then
        log_error "CICD_PIPELINES_RUNNER_TAG in $(basename "$yaml_file") is '$yaml_val' but PINNED_PIPELINE_VERSIONS says '$CICD_PIPELINES_RUNNER_TAG'"
      elif [ -n "$yaml_val" ]; then
        log_ok "CICD_PIPELINES_RUNNER_TAG in $(basename "$yaml_file") matches pinned ($yaml_val)"
      fi
    fi
  done
  echo ""
else
  log_warn "PINNED_PIPELINE_VERSIONS not found — skipping drift check"
  echo ""
fi

for platform in gitlab bitbucket github jenkins; do
  status=$(get_platform_status "$platform")

  if [ "$status" = "roadmap" ]; then
    echo "--- $platform: roadmap (skipped) ---"
    continue
  fi

  echo "--- $platform: $status ---"

  # Methodology templates
  for tmpl in stages-base gitflow-base gitflow-branch-policy gitflow-jobs container-tags artifact-publish-policy security-scanning; do
    check_template "$platform" "$tmpl" "$status" || true
  done

  # Runtime templates
  for tmpl in docker-runtime sbt-runtime sbt-artifact-tags sbt-docker-publish sbt-rust-runtime terraform-runtime terraform-module-publish; do
    check_template "$platform" "$tmpl" "$status" || true
  done

  # Check required flow jobs in gitflow-jobs
  flowjobs_file="$REPO_ROOT/${platform}/ci/.gitflow-jobs.yml"
  if [ -f "$flowjobs_file" ]; then
    check_jobs "$flowjobs_file" "$status" \
      "tomshley-cicd-flow-release-start" \
      "tomshley-cicd-flow-release-publish" \
      "tomshley-cicd-flow-release-finish" \
      "tomshley-cicd-flow-hotfix-finish"
  fi

  # Check required variables in gitflow-base
  gitflow_file="$REPO_ROOT/${platform}/ci/.gitflow-base.yml"
  if [ -f "$gitflow_file" ]; then
    check_variables "$gitflow_file" "$status" \
      "TOMSHLEY_CICD_FLOW_TYPE" \
      "TOMSHLEY_CICD_BUILD_REVISION" \
      "TOMSHLEY_CICD_BUILD_VERSION"
    check_jobs "$gitflow_file" "$status" \
      ".tomshley-cicd-debug" \
      ".tomshley-cicd-bootstrap"
  fi

  # Check required variables in container-tags
  ctags_file="$REPO_ROOT/${platform}/ci/.container-tags.yml"
  if [ -f "$ctags_file" ]; then
    check_variables "$ctags_file" "$status" \
      "BASE_CONTAINERS_TAG" \
      "BASE_CONTAINERS_TAG_LATEST"
  fi

  echo ""
done

echo "=== Summary ==="
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"

if [ "$ERRORS" -gt 0 ]; then
  echo "CONFORMANCE FAILED"
  exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
  echo "CONFORMANCE PASSED (with warnings)"
  exit 0
fi

echo "CONFORMANCE PASSED"
exit 0
