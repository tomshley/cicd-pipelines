# Roadmap

## Shipped Milestones

### v0.0.1 — GitLab Foundation

- [x] Common specs (10 files): naming-conventions, platform-status, stage-ordering,
      flow-types, flow-jobs, publish-policy, container-tags, security-scanning,
      runtimes, required-implementations
- [x] Conformance tests: conformance.sh, validate-gitlab.sh, validate-bitbucket.sh
- [x] GitLab CI templates (13 files): methodology + runtimes
- [x] GitLab runner images: base, scripts (24 shell scripts), sbtdockertofu
- [x] Build infrastructure: docker-bake.hcl, gitlab/Makefile
- [x] Root Makefile, internal .gitlab-ci.yml
- [x] Documentation: README.md, ROADMAP.md, SECURITY.md, .gitattributes

### v0.1.0 — Rust Runner

- [x] `sbtrustdockertofu` runner image (SBT + Rust + Docker + OpenTofu)
- [x] `.sbt-rust-runtime.yml` GitLab CI template
- [x] `BASE_CONTAINERS_UPSTREAM_TAG` bump to 0.4.1

### v0.2.0 — SBT Artifact Tags

- [x] `.sbt-artifact-tags.yml` dual-publish strategy (pinnable + rolling tags)
- [x] Develop revision prefix rename (`dev-` → `develop-`)

### v0.3.0 — SBT Docker Publish

- [x] `.sbt-docker-publish.yml` registered as required implementation
- [x] Pinned-version drift check for `BASE_CONTAINERS_UPSTREAM_TAG` in `.sbt-docker-publish.yml`

### v0.4.0 — Git Flow Lifecycle Jobs

- [x] `.gitflow-jobs.yml` with release-start, release-publish, release-finish, hotfix-finish
- [x] Full defensive validation (VERSION semver, tag existence, concurrent release guard, atomic push)
- [x] Token fallback chain with masking guidance
- [x] cicd-pipelines dogfoods its own gitflow-jobs.yml
- [x] Conformance tests for flow job names

### v0.5.0 — Toolbox Extraction + Three-Layer Architecture

- [x] Extract shell logic to `toolbox/` OCI image
- [x] Migrate runners to `COPY --from=toolbox` pattern
- [x] Move adapter YAML to `adapters/gitlab/ci/`
- [x] Delete `common/`, `gitlab/`, `bitbucket/` directories
- [x] Add `toolbox/tests/` test suite
- [x] Add `test-pinned-versions.sh` drift detection
- [x] Bitbucket adapter using toolbox scripts

## Planned Milestones

### v0.6.0 — Bidirectional Mirror (Vendor Contributions)

- [x] Wildcard glob-pattern support in `MIRROR_BRANCH_MAP` (e.g., `develop-*:develop-*`)
- [x] New `mirror/poll-remote.sh` for cron-driven reverse mirroring
- [x] GitLab adapter `tomshley-cicd-mirror-poll` job (scheduled pipelines)
- [x] Bitbucket adapter `mirror-poll` custom pipeline
- [x] Documentation: mirror poll variables + 3 deployment recipes (read-only, bidirectional push-driven, cron-driven)
- [x] Test: `test-mirror-wildcard.sh` for glob pattern matching

### v0.7.0 — Git LFS Support

- [ ] `toolbox/lib/lfs.sh` cross-platform LFS bootstrap script
- [ ] `adapters/gitlab/ci/.lfs-runtime.yml` GitLab hidden job (`.tomshley-cicd-lfs-runtime`)
- [ ] Consumers extend `.tomshley-cicd-lfs-runtime` for build/publish jobs needing LFS content
- [ ] Bitbucket equivalent as platform matures

### v0.8.0 — Bitbucket Pipelines

- [ ] Bitbucket CI templates implementing common specs
- [ ] Platform status: bitbucket → active

### v0.8.0 — Additional Runners

- [ ] `polyglot` runner image (SBT + Python + Node — for schema-registry)
- [ ] `infratofu` runner image (OpenTofu + Python — for terraform)
- [ ] `acceptance` runner image (Python + Node — for acceptance tests)

### v0.9.0 — GitHub Actions

- [ ] `github/ci/` composite actions + reusable workflows
- [ ] Platform status: github → active

### v1.0.0 — Stable

- [ ] All platforms active, full pipeline + template conformance
- [ ] Semver stability guarantee

## Issue Tracking

GitLab Issues with these labels:

- **Platform:** `platform:gitlab`, `platform:bitbucket`, `platform:github`
- **Type:** `type:template`, `type:pipeline`, `type:runner`, `type:spec`, `type:docs`
- **Priority:** `priority:high`, `priority:medium`, `priority:low`
