# Changelog

All notable changes to this project are documented in this file.

This project follows Semantic Versioning.

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
