#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

assert_contains() {
  local file="$1" pattern="$2" desc="$3"
  if grep -qE "$pattern" "$file"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (pattern: $pattern not found in $file)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local file="$1" pattern="$2" desc="$3"
  if ! grep -qE "$pattern" "$file"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (pattern: $pattern unexpectedly found in $file)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Validating GitLab templates against methodology ==="
echo ""

# --------------------------------------------------------------------------
# Stage ordering  (common/methodology/stage-ordering.yml)
# --------------------------------------------------------------------------
echo "--- Stage ordering ---"
STAGES_FILE="$REPO_ROOT/gitlab/templates/.stages-base.yml"

assert_contains "$STAGES_FILE" '^\s+-\s+\.pre'                "'.pre' stage exists"
assert_contains "$STAGES_FILE" '^\s+-\s+security\.pre-build'   "'security.pre-build' stage exists"
assert_contains "$STAGES_FILE" '^\s+-\s+build'                 "'build' stage exists"
assert_contains "$STAGES_FILE" '^\s+-\s+test'                  "'test' stage exists"
assert_contains "$STAGES_FILE" '^\s+-\s+security\.post-build'  "'security.post-build' stage exists"
assert_contains "$STAGES_FILE" '^\s+-\s+deploy'                "'deploy' stage exists"
assert_contains "$STAGES_FILE" '^\s+-\s+\.post'                "'.post' stage exists"

# Verify ordering constraints: security.pre-build line number < build line number, etc.
line_of() { grep -nE "$2" "$1" | head -1 | cut -d: -f1; }
order_ok=true
for pair in \
  "security\.pre-build:build" \
  "build:test" \
  "test:security\.post-build" \
  "security\.post-build:deploy"; do
  first="${pair%%:*}"
  second="${pair##*:}"
  l1=$(line_of "$STAGES_FILE" "^\s+-\s+$first")
  l2=$(line_of "$STAGES_FILE" "^\s+-\s+$second")
  if [ -n "$l1" ] && [ -n "$l2" ] && [ "$l1" -lt "$l2" ]; then
    echo "  PASS: $first BEFORE $second (line $l1 < $l2)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $first must come before $second (lines: $l1, $l2)"
    FAIL=$((FAIL + 1))
    order_ok=false
  fi
done

echo ""

# --------------------------------------------------------------------------
# Flow types  (common/methodology/flow-types.yml)
# --------------------------------------------------------------------------
echo "--- Flow types ---"
GITFLOW_FILE="$REPO_ROOT/gitlab/templates/.gitflow-base.yml"

# Feature flow
assert_contains "$GITFLOW_FILE" 'feature\\/.+'               "feature branch pattern in workflow rules"
assert_contains "$GITFLOW_FILE" 'FLOW_TYPE.*feature'         "FLOW_TYPE set to 'feature'"
assert_contains "$GITFLOW_FILE" 'BUILD_REVISION.*feature-'   "feature revision prefix"

# Hotfix flow
assert_contains "$GITFLOW_FILE" 'hotfix\\/.+'                "hotfix branch pattern in workflow rules"
assert_contains "$GITFLOW_FILE" 'FLOW_TYPE.*hotfix'          "FLOW_TYPE set to 'hotfix'"
assert_contains "$GITFLOW_FILE" 'BUILD_REVISION.*hotfix-'    "hotfix revision prefix"

# Release flow
assert_contains "$GITFLOW_FILE" 'release\\/.+'               "release branch pattern in workflow rules"
assert_contains "$GITFLOW_FILE" 'FLOW_TYPE.*release'         "FLOW_TYPE set to 'release'"
assert_contains "$GITFLOW_FILE" 'BUILD_REVISION.*rc-'        "release revision prefix (rc-)"

# Develop flow
assert_contains "$GITFLOW_FILE" 'develop'                    "develop branch in workflow rules"
assert_contains "$GITFLOW_FILE" 'FLOW_TYPE.*develop'         "FLOW_TYPE set to 'develop'"
assert_contains "$GITFLOW_FILE" 'BUILD_REVISION.*dev-'       "develop revision prefix"

# Main flow
assert_contains "$GITFLOW_FILE" 'main.*master'               "main/master branch in workflow rules"
assert_contains "$GITFLOW_FILE" 'FLOW_TYPE.*main'            "FLOW_TYPE set to 'main'"
assert_contains "$GITFLOW_FILE" 'BUILD_REVISION.*prod-'      "main revision prefix (prod-)"

# Tag flow
assert_contains "$GITFLOW_FILE" 'CI_COMMIT_TAG'             "tag trigger in workflow rules"
assert_contains "$GITFLOW_FILE" 'FLOW_TYPE.*tag'             "FLOW_TYPE set to 'tag'"

# MR pipelines present for feature, hotfix, release
assert_contains "$GITFLOW_FILE" 'merge_request_event.*feature' "MR pipeline rule for feature"
assert_contains "$GITFLOW_FILE" 'merge_request_event.*hotfix'  "MR pipeline rule for hotfix"
assert_contains "$GITFLOW_FILE" 'merge_request_event.*release' "MR pipeline rule for release"

echo ""

# --------------------------------------------------------------------------
# Publish policy  (common/methodology/publish-policy.yml)
# --------------------------------------------------------------------------
echo "--- Publish policy ---"
PUBLISH_FILE="$REPO_ROOT/gitlab/templates/.artifact-publish-policy.yml"

assert_contains "$PUBLISH_FILE" 'merge_request_event'                       "MR event rule present"
# MR → never (the merge_request_event rule has 'when: never' on the next line)
MR_LINE=$(grep -n 'merge_request_event' "$PUBLISH_FILE" | head -1 | cut -d: -f1)
if [ -n "$MR_LINE" ]; then
  NEXT_WHEN=$(sed -n "$((MR_LINE+1))p" "$PUBLISH_FILE")
  if echo "$NEXT_WHEN" | grep -qE 'when:\s*never'; then
    echo "  PASS: MR pipelines → never"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: MR pipelines should map to 'never'"
    FAIL=$((FAIL + 1))
  fi
fi

# develop → on_success
assert_contains "$PUBLISH_FILE" 'develop'                                   "develop publish rule present"
assert_contains "$PUBLISH_FILE" 'on_success'                                "develop publishes on_success"

# feature → manual
assert_contains "$PUBLISH_FILE" 'feature.*' "feature publish rule present"
# hotfix → manual
assert_contains "$PUBLISH_FILE" 'hotfix.*'  "hotfix publish rule present"
# release → manual
assert_contains "$PUBLISH_FILE" 'release.*' "release publish rule present"
# tag → manual
assert_contains "$PUBLISH_FILE" 'tag.*'     "tag publish rule present"

# Verify manual for feature, hotfix, release, tag
for flow in feature hotfix release tag; do
  FLOW_LINE=$(grep -n "FLOW_TYPE.*$flow" "$PUBLISH_FILE" | head -1 | cut -d: -f1)
  if [ -n "$FLOW_LINE" ]; then
    NEXT_WHEN=$(sed -n "$((FLOW_LINE+1))p" "$PUBLISH_FILE")
    if echo "$NEXT_WHEN" | grep -qE 'when:\s*manual'; then
      echo "  PASS: $flow → manual"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: $flow should map to 'manual'"
      FAIL=$((FAIL + 1))
    fi
  fi
done

# Default deny at the end
assert_contains "$PUBLISH_FILE" 'when:\s*never' "default deny (when: never) present"

echo ""

# --------------------------------------------------------------------------
# Flow jobs  (common/methodology/flow-jobs.yml)
# --------------------------------------------------------------------------
echo "--- Flow jobs ---"
JOBS_FILE="$REPO_ROOT/gitlab/templates/.gitflow-jobs.yml"

# flow-feature-start in stage .pre
assert_contains "$JOBS_FILE" '\.flow-feature-start:'          "flow-feature-start job defined"
assert_contains "$JOBS_FILE" 'feature\\/.+'                   "flow-feature-start triggers on feature branches"

# flow-release-start in stage .post, manual
assert_contains "$JOBS_FILE" '\.flow-release-start:'          "flow-release-start job defined"
assert_contains "$JOBS_FILE" 'develop'                        "flow-release-start triggers on develop"

# flow-release-publish in stage deploy
assert_contains "$JOBS_FILE" '\.flow-release-publish:'        "flow-release-publish job defined"

# flow-release-finish in stage .post, manual
assert_contains "$JOBS_FILE" '\.flow-release-finish:'         "flow-release-finish job defined"

# flow-hotfix-finish in stage .post, manual
assert_contains "$JOBS_FILE" '\.flow-hotfix-finish:'          "flow-hotfix-finish job defined"
assert_contains "$JOBS_FILE" 'hotfix\\/.+'                    "flow-hotfix-finish triggers on hotfix branches"

# Verify stages for each job
verify_job_stage() {
  local job_name="$1" expected_stage="$2"
  local job_line
  job_line=$(grep -n "\\.$job_name:" "$JOBS_FILE" | head -1 | cut -d: -f1)
  if [ -z "$job_line" ]; then
    echo "  FAIL: .$job_name not found"
    FAIL=$((FAIL + 1))
    return
  fi
  local stage_line
  stage_line=$(sed -n "$((job_line+1))p" "$JOBS_FILE")
  if echo "$stage_line" | grep -qE "stage:\s*$expected_stage"; then
    echo "  PASS: .$job_name stage is $expected_stage"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: .$job_name stage should be $expected_stage (got: $stage_line)"
    FAIL=$((FAIL + 1))
  fi
}

verify_job_stage "flow-feature-start"    "\.pre"
verify_job_stage "flow-release-start"    "\.post"
verify_job_stage "flow-release-publish"  "deploy"
verify_job_stage "flow-release-finish"   "\.post"
verify_job_stage "flow-hotfix-finish"    "\.post"

# Verify manual jobs have 'when: manual' INSIDE their rules: block (not job-level)
verify_job_manual() {
  local job_name="$1"
  local job_line
  job_line=$(grep -n "\\.$job_name:" "$JOBS_FILE" | head -1 | cut -d: -f1)
  if [ -z "$job_line" ]; then
    echo "  FAIL: .$job_name not found"
    FAIL=$((FAIL + 1))
    return
  fi
  # Search within 6 lines after the job header for 'when: manual' indented under a rule
  local block
  block=$(sed -n "$((job_line+1)),$((job_line+6))p" "$JOBS_FILE")
  if echo "$block" | grep -qE '^\s+when:\s*manual'; then
    echo "  PASS: .$job_name has when:manual inside rules block"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: .$job_name missing when:manual inside rules block"
    FAIL=$((FAIL + 1))
  fi
}

for job in flow-release-start flow-release-finish flow-hotfix-finish; do
  verify_job_manual "$job"
done

echo ""

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"
[ "$FAIL" -eq 0 ] || exit 1
