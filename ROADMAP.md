# Roadmap

## Versioned Milestones

### v0.0.1 — GitLab Foundation (current)

- [x] Common specs (10 files): naming-conventions, platform-status, stage-ordering,
      flow-types, flow-jobs, publish-policy, container-tags, security-scanning,
      runtimes, required-implementations
- [x] Conformance tests: conformance.sh, validate-gitlab.sh, validate-bitbucket.sh
- [x] GitLab CI templates (13 files): methodology + runtimes
- [x] GitLab runner images: base, scripts (24 shell scripts), sbtdockertofu
- [x] Build infrastructure: docker-bake.hcl, gitlab/Makefile
- [x] Root Makefile, internal .gitlab-ci.yml
- [x] Documentation: README.md, ROADMAP.md, SECURITY.md, .gitattributes

### v0.1.0 — Bitbucket Pipelines

- [ ] Bitbucket CI templates implementing common specs
- [ ] Bitbucket runner images (if needed — Bitbucket uses Atlassian-hosted runners)
- [ ] Platform status: bitbucket → active

### v0.2.0 — Complete Pipelines

- [ ] Batteries-included `pipeline-*.yml` for all 8 categories (GitLab first)
- [ ] Bitbucket pipeline equivalents
- [ ] Consumer usage examples

### v0.3.0 — Additional Runners

- [ ] `polyglot` runner image (SBT + Python + Node — for schema-registry)
- [ ] `infratofu` runner image (OpenTofu + Python — for terraform)
- [ ] `acceptance` runner image (Python + Node — for acceptance tests)

### v0.4.0 — GitHub Actions

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
