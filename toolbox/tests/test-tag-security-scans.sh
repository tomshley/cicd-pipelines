#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Test: the five covered GitLab analyzers have tag-only twins whose rules
# keep the upstream condition structure scoped to tags, and the image publish
# preflight delegates to the portable toolbox guard.
#
# Upstream analyzer rules match branch and merge-request pipelines only, so a
# tag pipeline — the one pipeline class that publishes a release — would run
# no scan. Each twin `extends` its analyzer (script, image, stage, and
# allow_failure keep flowing) and re-adds the analyzer's own disable,
# exclusion, license, file-detection, and FIPS conditions scoped to
# CI_COMMIT_TAG. These are local configuration assertions on the adapter
# YAML — they do not execute GitLab's scheduling engine.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
  if printf '%s\n' "$haystack" | grep -qF -- "$needle"; then
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
  if printf '%s\n' "$haystack" | grep -qE -- "$pattern"; then
    echo "  FAIL: $desc"
    echo "    Found:    $pattern"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
}

job_block() {
  # Print one job's block: its header through the line before the next
  # top-level key (column-0, non-blank, non-comment line).
  awk -v job="$1:" '
    $0 == job { inblock = 1; print; next }
    inblock && !/^  / && NF { exit }
    inblock { print }
  ' "$ADAPTER"
}

if_conditions() {
  # Ordered if: conditions of a job's rules (all are single-line here).
  printf '%s\n' "$1" | sed -n "s/^    - if: '\\(.*\\)'\$/\\1/p"
}

runnable_conditions() {
  # if: conditions of rules that do not say when: never — i.e. rules that can
  # actually add the job to a pipeline.
  printf '%s\n' "$1" | awk '
    /^    - if:/ {
      if (cond != "" && !never) print cond
      cond = $0; sub(/^    - if: '"'"'/, "", cond); sub(/'"'"'$/, "", cond)
      never = 0
      next
    }
    /^      when: never/ { never = 1 }
    END { if (cond != "" && !never) print cond }
  '
}

count_lines() { printf '%s' "$1" | grep -c .; }

check_twin() {
  # check_twin <analyzer> <disabled-var> <exclusion-condition-or-empty> <expected tag-run rules>
  local analyzer="$1" disabled="$2" exclusion="$3" expected_runs="$4"
  local twin="${analyzer}-tag" block conds runconds
  block="$(job_block "$twin")"
  conds="$(if_conditions "$block")"
  runconds="$(runnable_conditions "$block")"

  assert_contains "${twin} extends ${analyzer}" "$block" "extends: ${analyzer}"
  for forbidden in script image allow_failure stage; do
    assert_lacks "${twin} does not override ${forbidden}" "$block" "^  ${forbidden}:"
  done

  # The analyzer's own disable check stays first, ahead of every tag rule.
  assert_equal "${twin} disabled check is the first rule" \
    "\$${disabled} == \"true\" || \$${disabled} == \"1\"" \
    "$(printf '%s\n' "$conds" | sed -n '1p')"

  if [ -n "$exclusion" ]; then
    assert_equal "${twin} analyzer exclusion precedes tag rules" \
      "$exclusion" "$(printf '%s\n' "$conds" | sed -n '2p')"
  fi

  # Every rule that can run must be scoped to the tag event — no leftover
  # branch or merge-request condition may sneak in.
  assert_equal "${twin} has only the expected runnable rules" \
    "$expected_runs" "$(count_lines "$runconds")"
  assert_equal "${twin} runnable rules all require CI_COMMIT_TAG" \
    "$expected_runs" "$(printf '%s\n' "$runconds" | grep -c 'CI_COMMIT_TAG')"
  assert_lacks "${twin} has no runnable non-tag rule" \
    "$runconds" 'CI_COMMIT_BRANCH|CI_PIPELINE_SOURCE|CI_OPEN_MERGE_REQUESTS'
}

echo "=== test-tag-security-scans ==="

ADAPTER="$PROJECT_ROOT/adapters/gitlab/ci/adapter.yml"
BB_ADAPTER="$PROJECT_ROOT/adapters/bitbucket/ci/adapter.yml"

check_twin secret_detection SECRET_DETECTION_DISABLED "" 1
# Single quotes keep the expected YAML condition strings literal.
# shellcheck disable=SC2016
check_twin semgrep-sast SAST_DISABLED '$SAST_EXCLUDED_ANALYZERS =~ /semgrep/' 1
# shellcheck disable=SC2016
check_twin gemnasium-dependency_scanning DEPENDENCY_SCANNING_DISABLED '$DS_EXCLUDED_ANALYZERS =~ /gemnasium([^-]|$)/' 2
# shellcheck disable=SC2016
check_twin gemnasium-maven-dependency_scanning DEPENDENCY_SCANNING_DISABLED '$DS_EXCLUDED_ANALYZERS =~ /gemnasium-maven/' 2
# shellcheck disable=SC2016
check_twin gemnasium-python-dependency_scanning DEPENDENCY_SCANNING_DISABLED '$DS_EXCLUDED_ANALYZERS =~ /gemnasium-python/' 4

# Semgrep file detection: the tag twin references the upstream full-language
# exist list so it scans something on a repository that semgrep covers.
semgrep_block="$(job_block semgrep-sast-tag)"
assert_equal "semgrep-sast-tag uses the upstream exist list once" "1" \
  "$(printf '%s\n' "$semgrep_block" | grep -cF 'exists: !reference [.semgrep-exist-rules, exists]')"

# Dependency-scanning twins: every runnable rule requires the license
# feature, the FIPS rule precedes its non-FIPS counterpart, and each FIPS
# rule selects the -fips analyzer image.
for spec in \
  'gemnasium-dependency_scanning .gemnasium-shared-rule' \
  'gemnasium-maven-dependency_scanning .gemnasium-maven-shared-rule' \
  'gemnasium-python-dependency_scanning .gemnasium-python-shared-rule'; do

  twin="${spec%% *}-tag"
  shared="${spec##* }"
  block="$(job_block "$twin")"
  runconds="$(runnable_conditions "$block")"
  runs="$(count_lines "$runconds")"

  assert_equal "${twin} runnable rules all require the license feature" "$runs" \
    "$(printf '%s\n' "$runconds" | grep -c 'GITLAB_FEATURES =~ /\\bdependency_scanning\\b/')"
  assert_contains "${twin} FIPS rule runs before the plain rule" \
    "$(printf '%s\n' "$runconds" | sed -n '1p')" 'CI_GITLAB_FIPS_MODE == "true"'
  assert_lacks "${twin} final runnable rule is the plain image" \
    "$(printf '%s\n' "$runconds" | tail -1)" 'CI_GITLAB_FIPS_MODE'
  assert_contains "${twin} FIPS rules select the -fips image" "$block" 'DS_IMAGE_SUFFIX: "-fips"'
  assert_equal "${twin} references its shared file-detection rule twice" "2" \
    "$(printf '%s\n' "$block" | grep -cF "exists: !reference [${shared}, exists]")"
done

# Remediation policy mirrors upstream: only the plain gemnasium analyzer
# disables remediation under FIPS; maven and python set no override.
gem_block="$(job_block gemnasium-dependency_scanning-tag)"
maven_block="$(job_block gemnasium-maven-dependency_scanning-tag)"
python_block="$(job_block gemnasium-python-dependency_scanning-tag)"
assert_contains "gemnasium-dependency_scanning-tag disables remediation under FIPS" \
  "$gem_block" 'DS_REMEDIATE: "false"'
assert_lacks "gemnasium-maven-dependency_scanning-tag sets no remediation override" \
  "$maven_block" 'DS_REMEDIATE'
assert_lacks "gemnasium-python-dependency_scanning-tag sets no remediation override" \
  "$python_block" 'DS_REMEDIATE'

# Python custom requirements path: two runnable rules carry
# PIP_REQUIREMENTS_FILE, the FIPS variant first, and only the FIPS one pins
# the image suffix.
pip_conds="$(printf '%s\n' "$(runnable_conditions "$python_block")" | grep 'PIP_REQUIREMENTS_FILE' || true)"
assert_equal "gemnasium-python twin has both custom-requirements rules" "2" "$(count_lines "$pip_conds")"
assert_contains "gemnasium-python custom-requirements FIPS rule comes first" \
  "$(printf '%s\n' "$pip_conds" | sed -n '1p')" 'CI_GITLAB_FIPS_MODE == "true"'
assert_lacks "gemnasium-python custom-requirements plain rule has no FIPS gate" \
  "$(printf '%s\n' "$pip_conds" | sed -n '2p')" 'CI_GITLAB_FIPS_MODE'

# Secret detection on a tag needs the whole reachable history: the upstream
# default compares only the last commit when the before-SHA is all zeros.
sd_block="$(job_block secret_detection-tag)"
assert_contains "secret_detection-tag clones full history" "$sd_block" 'GIT_DEPTH: "0"'
# shellcheck disable=SC2016  # single quotes keep the expected YAML variable literal
assert_contains "secret_detection-tag scans history reachable from the tagged SHA" "$sd_block" \
  'SECRET_DETECTION_LOG_OPTIONS: "$CI_COMMIT_SHA"'

# The preflight fragment gates on the tag, requires the canonical image
# variable, and delegates to the toolbox guard.
fragment="$(job_block '.tomshley-cicd-image-tag-guard')"
assert_contains "image publish preflight gates on CI_COMMIT_TAG" "$fragment" 'CI_COMMIT_TAG'
assert_contains "image publish preflight delegates to the toolbox guard" "$fragment" 'verify/image-tag-guard.sh'
assert_contains "image publish preflight requires the canonical image variable" "$fragment" 'TOMSHLEY_CICD_REGISTRY_IMAGE:?'

# Bitbucket exposes the same guard as a reusable anchor gating on its own
# tag variable (the anchor itself is executed against a fake curl in
# test-publish-recipes).
bb_guard="$(awk '/- &image-tag-guard \|/ { inblk = 1 } inblk { print } inblk && /^ *fi$/ { exit }' "$BB_ADAPTER")"
assert_contains "bitbucket anchor gates on BITBUCKET_TAG" "$bb_guard" 'BITBUCKET_TAG'
assert_contains "bitbucket anchor delegates to the toolbox guard" "$bb_guard" 'verify/image-tag-guard.sh'

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
