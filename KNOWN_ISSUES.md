# Known Issues

Issues identified during code review that are deferred for future work.

## Security

### Supply chain risk: `curl | bash` for secure files download

**Files:** `cicd-bootstrap-envvars-gitlab.sh`, `cicd-bootstrap-gitlab-tf-backends-local.sh`, `cicd-bootstrap-gitlab-tf-backends-remote.sh`, `gitlab/ci/.sbt-runtime.yml`, `gitlab/ci/.terraform-runtime.yml`

Five files download the GitLab secure files installer via
`curl --silent "https://gitlab.com/.../download-secure-files/-/raw/main/installer" | bash`.
This pulls from `main` branch with no checksum or pinned commit SHA, creating a
supply chain risk if that repository is compromised.

**Mitigation:** Pin to a specific commit SHA or vendor the installer script.

### `GL_PASSWORD` credential exposure in git remote URL

**File:** `cicd-bootstrap-gitlab-gitconfig.sh`

The script embeds `GL_PASSWORD` in the git remote URL:
`https://${GITLAB_USER_LOGIN}:${GL_PASSWORD}@...`. Any subsequent
`git remote -v`, git error output, or verbose logging will expose the
credential in CI job logs. Use `git credential helper` or `GIT_ASKPASS`
instead.

### `GL_PASSWORD` passed via `PRIVATE-TOKEN` header

**File:** `cicd-flow-feature-gitlab-merge-request.sh`

Uses `PRIVATE-TOKEN:${GL_PASSWORD}` header for GitLab API calls. If
`GL_PASSWORD` is a personal access token, it has broader scope than
necessary. Should use `JOB-TOKEN:${CI_JOB_TOKEN}` instead.

## Flow Scripts (legacy, restored from git history)

### `cicd-flow-feature-update.sh` — commits but never pushes

The script creates a `release/` branch and commits a version bump locally, but
never pushes to the remote. The commit is lost when the CI container exits.

### `GIT_MERGE_AUTOEDIT` not unset in `cicd-flow-feature-merge-upstream.sh`

Sets `GIT_MERGE_AUTOEDIT=no` but never unsets it. Benign in a CI container
(environment is ephemeral), but inconsistent with the pattern in
`cicd-flow-release-finish.sh` and `cicd-flow-hotfix-finish.sh` which also
don't unset it.

## Version Handling

### gawk version bump always prepends `v` prefix

In `gitlab/runners/scripts/files/cicd-exports.sh`, the gawk script that
computes `TOMSHLEY_CICD_BUILD_VERSION_NEXT` always outputs `v%d.%d.%d`
regardless of whether the input `VERSION` file contains a `v` prefix.
Currently works because `VERSION` contains `0.0.1` (no `v`) and gawk
coerces `v0` to `0` — but the output always has `v`, which may not match
the input format.

### `TF_STATE_NAME` defaults to `CI_PROJECT_NAME`

`gitlab/runners/scripts/files/cicd-exports.sh` line 23 uses
`TF_STATE_NAME="${TF_STATE_NAME:-${CI_PROJECT_NAME}}"`. This is a reasonable
default but may not match existing Terraform state names for consumers who
previously used a different convention. Consumers should set `TF_STATE_NAME`
explicitly via CI variables if their state name differs from the project name.

## Conformance Tests

### `conformance.sh` hardcodes template names instead of reading spec

The conformance test hardcodes the list of methodology and runtime templates
rather than parsing `common/specs/required-implementations.yml`. Adding a
new template to the spec won't automatically be tested until the script is
updated.

**Target:** v0.0.2 enhancement — parse YAML spec to drive test loop.

## Minor / Style (legacy scripts)

- `TOMSHLEY_PROVISIONING_CI_PIPELINES` exported but never assigned in `cicd-exports.sh`
- `cicd-flow-release-finish.sh:35` has trailing `\` after semicolon (benign)
- Unused `ARG TOMSHLEY_DOCKERS_BUILD_REF` in `sbtdockertofu/Dockerfile`
- Unquoted branch names in `cicd-flow-release-finish.sh` and `cicd-flow-hotfix-finish.sh` git operations (e.g. `release/${TOMSHLEY_CICD_BUILD_VERSION}` should be quoted)
- Double-sourcing of `cicd-exports.sh` in flow scripts (idempotent but wasteful)
- `apk info -L` debug leftover in `gitlab/runners/base/Dockerfile`
