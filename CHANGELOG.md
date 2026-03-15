# Changelog

All notable changes to this project are documented in this file.

This project follows Semantic Versioning.

---

## v0.5.0 (unreleased)

### Breaking Changes

**Three-Layer Architecture Migration** — Runtime templates deleted, replaced with toolbox + runner images.

**Deleted templates** (consumers must remove these from their includes):
- `.sbt-runtime.yml`
- `.sbt-rust-runtime.yml`
- `.sbt-allure-runtime.yml`
- `.sbt-artifact-tags.yml`
- `.sbt-docker-publish.yml`
- `.terraform-runtime.yml`
- `.terraform-module-publish.yml`
- `.acceptance-runtime.yml`
- `.docs-runtime.yml`

**Migration path:**
1. Update includes from `/gitlab/ci/` to `/adapters/gitlab/ci/`
2. Remove deleted runtime templates from your includes
3. Use runner images with toolbox baked in (image variables switch from `BASE_CONTAINERS_*` to `CICD_PIPELINES_*`)
4. Pin `ref:` to `v0.5.0` or later

**Bootstrapping note:** The initial v0.5.0 release uses `CICD_PIPELINES_RUNNER_TAG: "0.4.20"` as default (pre-toolbox runners) to allow the cicd-pipelines project to publish its own v0.5.0 runners. After runner images are published, a hotfix will update defaults to `0.5.0`. Consumers should explicitly set `CICD_PIPELINES_RUNNER_TAG: "0.5.0"` in their CI/CD variables when adopting v0.5.0 adapters.

### Added
- `toolbox/` — Platform-agnostic shell scripts packaged as OCI image
- `toolbox/tests/` — Unit and integration test suite
- `test-pinned-versions.sh` — Drift detection for PINNED_PIPELINE_VERSIONS
- `test-flow-hotfix-lifecycle.sh` — Integration tests for hotfix-finish (auto-bump and skip-bump paths)
- `test-flow-release-continue.sh` — Integration test for release-start → release-continue → release-finish lifecycle
- `test-flow-release-cancel-new.sh` — Integration test for release-start → release-cancel-new → release-finish lifecycle
- `test-flow-release-start-skip.sh` — Integration test for release-start → release-start-skip → release-finish lifecycle
- `adapters/bitbucket/ci/adapter.yml` — Bitbucket adapter using toolbox scripts
- Runner images now `COPY --from=toolbox` to get gitflow/mirror scripts at `/opt/tomshley-cicd-pipelines-toolbox/`

### Changed
- **Architecture:** Moved from monolithic inline-YAML-shell to three-layer (toolbox → runners → adapters)
- **Directory structure:** Deleted `common/`, `gitlab/`, `bitbucket/`; added `toolbox/`, `runners/`, `adapters/`
- **Adapter paths:** `/gitlab/ci/` → `/adapters/gitlab/ci/`
- **Image variables:** `BASE_CONTAINERS_REGISTRY/TAG` → `CICD_PIPELINES_REGISTRY/RUNNER_TAG` in adapter YAMLs
- Runners: Moved from `gitlab/runners/` to `runners/`, removed inline scripts
- Build system: Moved `docker-bake.hcl` and `Makefile` to project root

### Fixed
- Stdout contamination in lib functions, force-push implementation, orphan branch handling, pinned-version drift detection, mirror early-exit on first failure, trailing newlines, release-cancel-new self-referential branch check
- Added documentation comments in GitLab and Bitbucket adapters clarifying that publish extension points require `BASE_CONTAINERS_*` variables to be defined by consumers

---

## v0.4.1

### Added
- `tomshley-cicd-flow-hotfix-publish`: no-op extension point on `hotfix/*` branches, mirroring `release-publish`. Consumers override to add hotfix artifact publishing.
- `TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX` variable: configurable prefix for merge/tag commit messages (default: `"Tomshley CI Pipeline"`). Set in CI/CD variables to override.
- `flow-hotfix-publish` added to `common/specs/flow-jobs.yml` and conformance test coverage.

### Changed
- `build-runner-images`: `release/*` and `hotfix/*` branches changed from auto to `when: manual` — skip builds when only templates changed.
- `publish-runner-images` retained with `.flow-artifact-publish` for develop (auto), tag (manual), and manual on feature/hotfix/release. Gitflow publish extension points remain no-ops.
- `.flow-artifact-publish`: added `allow_failure: true` to all manual rules (feature, hotfix, release, tag) so manual publish jobs don't block downstream stages.
- `build-runner-images`: added `allow_failure: true` to manual rules (feature, release, hotfix) so optional builds don't block deploy or `.post` stages.
- `tomshley-cicd-flow-release-publish` and `tomshley-cicd-flow-hotfix-publish`: changed from `when: on_success` to `when: manual` + `allow_failure: true` — extension points are now opt-in triggers, preventing unintended auto-publish when consumers override with real logic.
- README.md: added Git Flow Lifecycle Jobs section, documented variables, override pattern, updated consumer usage example to v0.4.0, fixed file path prefixes.
- ROADMAP.md: updated to reflect actual shipped milestones (v0.0.1–v0.4.0).

---

## v0.4.0

### Added
- `.gitflow-jobs.yml` GitLab CI template: automated gitflow lifecycle jobs for release and hotfix workflows.
  - `.tomshley-cicd-git-push-config` hidden job: Alpine-based git push configuration with token fallback chain (`TOMSHLEY_CICD_GIT_PUSH_TOKEN` → `GL_PASSWORD` → `CI_JOB_TOKEN`).
  - `tomshley-cicd-flow-release-start`: manual job on develop — creates `release/*` branch, bumps VERSION.
  - `tomshley-cicd-flow-release-publish`: extension point on `release/*` branches for consumer-defined publish logic.
  - `tomshley-cicd-flow-release-finish`: manual job on `release/*` — merges to main + develop, tags, deletes release branch.
  - `tomshley-cicd-flow-hotfix-finish`: manual job on `hotfix/*` — bumps VERSION, merges to main + develop, tags, deletes hotfix branch.
- `.gitflow-jobs.yml` included in `cicd-pipelines` own `.gitlab-ci.yml`.
- Conformance test coverage for flow job names and `.tomshley-cicd-git-push-config` hidden job.
- Regex escaping in `check_jobs` conformance function for dot-prefixed hidden job names.

### Security
- Token masking guidance documented in `.gitflow-jobs.yml` header for `TOMSHLEY_CICD_GIT_PUSH_TOKEN` and `GL_PASSWORD`.

---

## v0.3.0

### Added
- `sbt-artifact-tags` and `sbt-docker-publish` registered in `required-implementations.yml`.
- Conformance test coverage for `sbt-artifact-tags` and `sbt-docker-publish` template existence.
- Pinned-version drift check for `BASE_CONTAINERS_UPSTREAM_TAG` in `.sbt-docker-publish.yml`.

### Changed
- `BASE_CONTAINERS_UPSTREAM_TAG` in `.sbt-docker-publish.yml` bumped from `0.3.4` to `0.4.1`.

---

## v0.2.0

### Added
- `.sbt-artifact-tags.yml` GitLab CI template: dual-publish strategy with pinnable (`1.4.1-develop-abc1234`) and rolling (`1.4.1-develop`) SBT artifact tags for branch/MR pipelines.

### Changed
- Develop branch revision prefix renamed from `dev-{SHORT_SHA}` to `develop-{SHORT_SHA}` in `flow-types.yml` spec and `.gitflow-base.yml` implementation for consistency with other flow type prefixes.

---

## v0.1.1

### Fixed
- `sbtrustdockertofu` runner: added `build-base` Alpine package to provide `cc` linker required by Rust `cc` crate during `cargo build`.

---

## v0.1.0

### Added
- `sbtrustdockertofu` runner image: SBT + Rust + Docker + OpenTofu CI runner for projects that compile native Rust binaries alongside JVM artifacts.
- `.sbt-rust-runtime.yml` GitLab CI template with pipeline-level `CICD_PIPELINES_RUNNER_TAG` default.
- `sbt-rust-runtime` registered in `runtimes.yml` and `required-implementations.yml` specs.
- Conformance test coverage for `sbt-rust-runtime` template existence and `CICD_PIPELINES_RUNNER_TAG` drift.

### Changed
- `BASE_CONTAINERS_UPSTREAM_TAG` bumped from `0.3.4` to `0.4.1` across `PINNED_PIPELINE_VERSIONS`, `.gitlab-ci.yml`, and `.docker-runtime.yml`.

---

## v0.0.1

### Added
- Initial cicd-pipelines repository foundation.
- GitLab shared CI templates: stages, gitflow, branch policy, container tags, artifact publish, security scanning.
- `sbtdockertofu` runner image: SBT + Docker + OpenTofu CI runner.
- `.sbt-runtime.yml`, `.docker-runtime.yml`, `.terraform-runtime.yml`, `.terraform-module-publish.yml` templates.
- Conformance test suite (`conformance.sh`, `validate-gitlab.sh`, `validate-bitbucket.sh`).
- `docker-bake.hcl` build system for runner images.
- `PINNED_PIPELINE_VERSIONS` for cross-repo version pinning.
