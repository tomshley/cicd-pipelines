# Known Issues

Issues identified during code review that are deferred for future work.

## Security

### Supply chain risk: `curl | bash` for secure files download

**Files:** `cicd-bootstrap-envvars-gitlab.sh`, `cicd-bootstrap-gitlab-tf-backends-local.sh`, `cicd-bootstrap-gitlab-tf-backends-remote.sh`

Three bootstrap scripts download the GitLab secure files installer via
`curl --silent "https://gitlab.com/.../download-secure-files/-/raw/main/installer" | bash`.
This pulls from `main` branch with no checksum or pinned commit SHA, creating a
supply chain risk if that repository is compromised.

**Mitigation:** Pin to a specific commit SHA or vendor the installer script.

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

### Hardcoded `TF_STATE_NAME` in `cicd-exports.sh`

`gitlab/runners/scripts/files/cicd-exports.sh` line 23 sets
`TF_STATE_NAME=tomshley-breakground-provisioning` which is project-specific
and shouldn't be baked into a reusable pipeline's runner image. Consumers
should set this via CI variables.

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
