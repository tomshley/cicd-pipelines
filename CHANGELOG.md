# Changelog

All notable changes to this project are documented in this file.

This project follows Semantic Versioning.

---

## v0.6.2 — 2026-05-28

### Added
- **`docker/switch-to-push-auth.sh` toolbox helper** — Idempotent, sourced script that unsets `DOCKER_AUTH_CONFIG` between `docker buildx build` and `docker push`. Enables pipelines to keep `DOCKER_AUTH_CONFIG` set during the build step (so base images can be pulled from registries reachable only via a group-level / cross-org deploy token) and switch to file-based auth from `~/.docker/config.json` for push (using the platform's job token, which has write access to the current project). Must be sourced (`. ` or `source`) — not executed — so the `unset` propagates to the calling shell. Documented in `toolbox/VARIABLES.md` under "Docker Helpers".

### Changed
- **GitLab adapter `.tomshley-docker-runtime`** — Added a guidance comment in `before_script` warning against placing `unset DOCKER_AUTH_CONFIG` there (which would prevent `docker buildx build` from pulling cross-org base images) and pointing consumers to the new helper for use between build and push. No behaviour change for existing pipelines. The Bitbucket adapter is unaffected because it does not export `DOCKER_AUTH_CONFIG` (image-level credentials are used per `image: { username, password }` instead).

---

## v0.6.1 — 2026-05-22

### Fixed
- **Mirror sync wildcard rename guard restored** — During the v0.6.0 release branch rebase, the wildcard rename/asymmetric guard in `mirror/sync.sh` was inadvertently dropped, causing mappings like `develop-*:release-*` to silently push to the source branch name instead of being refused. The guard is re-applied: only identity wildcards (`foo-*:foo-*`) are accepted; rename/asymmetric patterns are skipped with a warning.
- **Mirror poll hardening restored** — Re-applied lost fixes in `mirror/poll-remote.sh`:
  - Token URL rewrite uses shell parameter expansion instead of `sed` so tokens containing `|`, `&`, `\`, `/` no longer corrupt the URL.
  - `http.extraheader` is unset before fetching from `poll-remote` to avoid leaking origin credentials.
  - HEAD detection uses the full refname (`refs/remotes/poll-remote/HEAD`) so a literal branch named `HEAD` is not silently dropped.
  - Matched branches are deduplicated before push to prevent inflated counts when a branch matches multiple patterns.
  - `set -f` disables pathname expansion across the iteration and dedup steps; explicit `set +f` on exit.
  - SSH key setup warns when the key is set but the URL is not SSH, or when the host cannot be derived from the URL.

---

## v0.6.0 — 2026-05-22

### Added
- **Bidirectional Mirror (Vendor Contributions)** — Extends the existing mirror-sync pattern to support vendor/OSS contribution workflows where external contributors push branches to a secondary platform (e.g., Bitbucket) that are then mirrored back to the source-of-truth (e.g., GitLab).
  - **Wildcard glob-pattern support** in `TOMSHLEY_CICD_MIRROR_BRANCH_MAP` — Enables branch patterns like `contrib/*:contrib/*` to automatically mirror all contributor branches without manual configuration per branch. Only identity glob patterns are supported; rename patterns (e.g., `develop-*:release-*`) are refused with a warning.
  - **New `mirror/poll-remote.sh` script** — Cron/scheduled-driven reverse mirroring. Fetches a remote and pushes matching branches to local origin. Use case: when the external platform has no CI or as a backstop for push-driven mirroring.
  - **GitLab adapter `tomshley-cicd-mirror-poll` job** — Wired to `$CI_PIPELINE_SOURCE == "schedule"` for scheduled reverse sync.
  - **Bitbucket adapter `mirror-poll` custom pipeline** — Manual or scheduled execution for reverse sync.
  - **Loop prevention** — Forward (`MIRROR_BRANCHES`) and reverse (`MIRROR_POLL_BRANCH_PATTERNS`) branch sets are disjoint by design, preventing infinite mirror loops.
  - **Documentation** — New `VARIABLES.md` section with mirror poll variables and 3 deployment recipes:
    - Recipe A: Read-only mirror (existing pattern)
    - Recipe B: Contributor workflow (push-driven, bidirectional)
    - Recipe C: Cron-driven reverse sync (no external CI required)
  - **Tests**:
    - `test-mirror-wildcard.sh` validates identity glob patterns push to correct refs with correct SHAs
    - `test-mirror-wildcard-rename.sh` validates asymmetric/rename glob mappings are refused with warnings
    - `test-adapter-conformance.sh` now derives expected toolbox-script set from disk rather than hard-coded count

### Fixed
- **Mirror sync wildcard rename guard** — `sync.sh` now refuses unsupported wildcard rename mappings (e.g., `develop-*:release-*`) with a warning instead of silently pushing to the wrong ref. Only identity wildcards are supported.
- **Mirror poll token URL rewrite** — Replaced `sed`-based token injection with shell parameter expansion to safely handle tokens containing special characters (`|`, `&`, `\`, `/`).
- **Wildcard detection** — Broadened from `*` to include `?` and `[` for robust validation of glob patterns.
- **SSH key setup warnings** — `poll-remote.sh` now provides comprehensive warnings matching `sync.sh` for missing or misconfigured SSH keys.
- **Branch deduplication** — `poll-remote.sh` deduplicates matched branches before push loop to prevent inflated push counts.
- **Pathname expansion safety** — Added `set -f` to disable pathname expansion during branch iteration and deduplication in `poll-remote.sh`.
- **HEAD branch detection** — Uses full refname to allow literal branches named "HEAD" while excluding the symbolic `refs/remotes/poll-remote/HEAD`.
- **Credential leakage prevention** — Moved `http.extraheader` unset before fetch operations in `poll-remote.sh` to prevent stale credentials from being sent.

---

## v0.5.5

### Fixed
- **GitLab Secure Files download broken** — The deprecated `download-secure-files` binary (hosted at `gitlab.com/gitlab-org/incubation-engineering/mobile-devops/download-secure-files`) started returning HTTP 403 on 2026-04-14, breaking all pipelines that rely on GitLab Secure Files for secrets bootstrap.
  - `gitlab-secure-files.sh` toolbox script rewritten to use the GitLab REST API directly (`GET /projects/:id/secure_files` + per-file download). No external binary dependency.
  - Adapter `.tomshley-cicd-secure-files` inline fallback updated with the same REST API approach.
  - Toolbox script paginates and supports jq (preferred) or python3 (fallback) for JSON parsing.
  - Adapter inline fallback fetches a single page (100 files); sufficient for all current projects.

### Added
- `pythondocker` runner image — Python3 + pip + Docker + toolbox. Lean runner for Python/FastAPI service CI (build, test, containerize) without JVM overhead.
- `awsdockertofu` runner image — Python3 + pip + AWS CLI + Docker + OpenTofu + toolbox. Runner for AWS infrastructure CI with native `aws eks get-token` support, eliminating the need for in-job `pip install awscli`.

---

## v0.5.4

### Fixed
- Use `bash` prefix for all toolbox script executions.
- Remove `-u` from POSIX fallback to prevent variable leak in non-bash shells.

### Added
- Decouple flow image from runner image — new `CICD_PIPELINES_FLOW_IMAGE` variable allows gitflow/mirror jobs to use a lightweight base image instead of the full runner.
- `TOMSHLEY_CICD_TOOLBOX_ROOT` variable for explicit toolbox path resolution.
- Adapter parity test (`test-adapter-parity.sh`) to validate GitLab and Bitbucket adapters stay in sync.

### Changed
- Bitbucket adapter updated with flow image decoupling and toolbox root support.
- GitLab adapter updated with flow image decoupling and toolbox root support.
- Reverted `dependencies: []` on git-push and mirror configs (caused unintended side-effects).

---

## v0.5.3

### Added
- `docker/buildx-setup.sh` — Toolbox script for platform-agnostic Buildx builder setup. Uses the default builder instead of creating a nested `docker-container` builder, which requires `sysfs` mount that rootless DinD cannot provide. Called by any adapter that runs Docker builds inside rootless DinD (GitLab, Bitbucket, GitHub Actions, etc.).

### Fixed
- GitLab adapter `.tomshley-docker-runtime` now calls the toolbox `docker/buildx-setup.sh` when available, with an inline fallback for base-containers images that don't have the toolbox. Restores `publish:docker` jobs on GitLab SaaS runners where the nested BuildKit container failed with `operation not permitted` on `sysfs` mount.

### Changed
- Internal self-hosting bootstrap pin in this repository's `.gitlab-ci.yml` now points to runner image `0.5.2` while the `v0.5.3` tag pipeline publishes the updated runner images.

---

## v0.5.2

### Added
- `secrets/gitlab-secure-files.sh` — Toolbox script wrapping the GitLab Secure Files installer with `TOMSHLEY_CICD_SECRETS_BOOTSTRAP` guard variable and graceful no-op behavior.
- `secrets/bitbucket-bootstrap.sh` — Default Bitbucket pre-`toolbox-entry.sh` hook. No-op placeholder that preserves the secrets-bootstrap lifecycle position for consumer-provided providers.
- `secrets/delinea.sh` — Placeholder for future Delinea secrets provider integration.
- `.tomshley-cicd-secure-files` hidden job in GitLab adapter — consumer-overridable secrets bootstrap. Uses the toolbox script when available and falls back to the GitLab installer in non-toolbox images. Override to use Delinea, Vault, or any other provider.
- `TOMSHLEY_CICD_SECRETS_BOOTSTRAP` variable — set to `"false"` (per-job or project-wide) to skip secrets download.

### Changed
- Secrets bootstrap now runs before `toolbox-entry.sh` in both adapters. On GitLab it runs in toolbox-based job chains: `.tomshley-cicd-bootstrap`, `.tomshley-cicd-git-push-config`, `.tomshley-cicd-mirror-config`. Not added to `.before-artifact-tags` because it feeds into `.tomshley-docker-runtime` which uses base-containers images without the toolbox. On Bitbucket it runs in the shared `&toolbox-setup` anchor.
- Replaced `curl | bash` installer execution with tempfile download + explicit execution to make download failures observable in both toolbox and non-toolbox bootstrap paths.
- Removed inline `curl | bash` from `.tomshley-cicd-git-push-config` and `.tomshley-cicd-mirror-config` — replaced with `!reference [.tomshley-cicd-secure-files, before_script]` (DRY).

---

## v0.5.1

### Fixed
- Self-hosting release bootstrap: pinned this repository's internal `.gitlab-ci.yml` runner override to the published `0.5.0` runner image so the `v0.5.1` release pipeline could build and publish the new tag before consumer defaults moved forward.

---

## v0.5.0

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

**Renamed/replaced variables:**
- `TOMSHLEY_CICD_GIT_PUSH_TOKEN` → `TOMSHLEY_CICD_FLOW_PUSH_TOKEN` (now optional; native CI auth is default)
- `TOMSHLEY_CICD_GIT_PUSH_USER` → `TOMSHLEY_CICD_FLOW_PUSH_USER` (adapter provides platform default, e.g. `oauth2` for GitLab)

**Removed variables:**
- `TOMSHLEY_CICD_PROJECT_URL` — removed; origin remote URL from CI clone is used as-is
- `GL_PASSWORD` fallback — removed from token fallback chain
- ASKPASS tempfile mechanism — removed; origin URL rewrite replaces it

**Migration path:**
1. Update includes from `/gitlab/ci/` to `/adapters/gitlab/ci/`
2. Remove deleted runtime templates from your includes
3. Use runner images with toolbox baked in (image variables switch from `BASE_CONTAINERS_*` to `CICD_PIPELINES_*`)
4. Rename `TOMSHLEY_CICD_GIT_PUSH_TOKEN` → `TOMSHLEY_CICD_FLOW_PUSH_TOKEN` in CI/CD variables (or remove if not needed — native CI auth works without it)
5. Remove `TOMSHLEY_CICD_GIT_PUSH_USER` (adapter defaults handle this; only set `TOMSHLEY_CICD_FLOW_PUSH_USER` on Bitbucket with App Password)
6. GitLab: enable "Allow Git push requests to the repository" in Settings → CI/CD → Job token permissions
7. Pin `ref:` to `v0.5.0` or later

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
- Internal self-hosting release-branch bootstrap: documented and applied `CICD_PIPELINES_RUNNER_TAG` override to a published `develop-*` runner image so gitflow jobs do not block on unavailable pinned release images during `v0.5.0` cutover

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
