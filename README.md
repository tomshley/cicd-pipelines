# cicd-pipelines

Spec-driven, multi-CI-platform templates and runner images for Tomshley projects.

## Architecture

    toolbox/                      Platform-agnostic shell scripts (OCI image)
    ├── scripts/                  Gitflow, mirror, platform abstraction
    ├── tests/                    Unit + integration tests
    ├── Dockerfile                Toolbox OCI image (COPY'd into runners)
    └── VARIABLES.md              Environment variable documentation

    runners/                      Build environment images (toolbox baked in)
    ├── sbtdockertofu/            Scala + Docker + Terraform runner
    ├── sbtallure/                Scala + Allure test reporting runner
    └── sbtrustdockertofu/        Scala + Rust + Docker + Terraform runner

    adapters/                     Platform-specific YAML templates
    ├── gitlab/ci/adapter.yml     GitLab CI adapter (all stages, jobs, policies)
    └── bitbucket/ci/adapter.yml  Bitbucket Pipelines adapter

    docker-bake.hcl               BuildKit bake file (toolbox + runners)
    Makefile                      Build/test/push targets

## Naming Conventions

| Scope | Pattern | Example |
|---|---|---|
| Variables | `TOMSHLEY_CICD_{NAME}` | `TOMSHLEY_CICD_FLOW_TYPE` |
| GitLab hidden jobs | `.tomshley-cicd-{name}` | `.tomshley-cicd-debug` |
| GitLab flow jobs | `tomshley-cicd-flow-{lifecycle}` | `tomshley-cicd-flow-release-start` |
| Runner images | `cicd-runner-{name}` | `cicd-runner-sbtdockertofu` |

## Consumer Usage (GitLab)

In your project's `.gitlab-ci.yml`:

    include:
      - project: 'tomshley/brands/global/tware/tech/products/provisioning/cicd-pipelines'
        ref: 'v0.5.0'
        file: '/adapters/gitlab/ci/adapter.yml'

    variables:
      CICD_PIPELINES_RUNNER_TAG: "0.5.0"   # pin to runner image version (match your ref)

For self-hosting this repository before `0.5.0` runner images are published, temporarily
override `CICD_PIPELINES_RUNNER_TAG` in this repo's `.gitlab-ci.yml` to a published
`develop-*` tag.

## Git Flow Lifecycle Jobs

The adapter includes automated gitflow lifecycle management:

### Release Jobs

| Job | Stage | Trigger | Action | When to Use |
|---|---|---|---|---|
| `tomshley-cicd-flow-release-start` | `.post` | Manual on `develop` | Increments VERSION by 1, creates `release/*` branch | **Normal release flow** — no release branch exists |
| `tomshley-cicd-flow-release-continue` | `.post` | Manual on `develop` | Checks out existing `release/*` branch | **Resume work** on existing release |
| `tomshley-cicd-flow-release-cancel-new` | `.post` | Manual on `develop` | Deletes existing `release/*`, creates fresh from develop | **Abandon and replace** current release (destructive) |
| `tomshley-cicd-flow-release-start-skip` | `.post` | Manual on `develop` | Increments VERSION by 2, creates new `release/*` | **Skip version** — leave old release untouched, create next |
| `tomshley-cicd-flow-release-publish` | `deploy` | Manual on `release/*` | No-op extension point (override to publish RCs) | Override to add RC publishing logic |
| `tomshley-cicd-flow-release-finish` | `.post` | Manual on `release/*` | Merges to main + develop, tags, deletes branch | Complete the release |

### Hotfix Jobs

| Job | Stage | Trigger | Action |
|---|---|---|---|
| `tomshley-cicd-flow-hotfix-publish` | `deploy` | Manual on `hotfix/*` | No-op extension point (override to publish hotfix artifacts) |
| `tomshley-cicd-flow-hotfix-finish` | `.post` | Manual on `hotfix/*` | Bumps VERSION, merges to main + develop, tags, deletes branch |

### Prerequisites

The gitflow jobs push branches, tags, and merges to the repository.
Go to **Settings → CI/CD → Job token permissions** and enable **"Allow Git push requests to the repository"**.

**Pipeline triggering:** By default, CI_JOB_TOKEN push auth is used (via CI_REPOSITORY_URL).
However, GitLab's anti-cascade protection means CI_JOB_TOKEN pushes do **not** trigger
downstream pipelines. If you need pushed branches/tags to trigger pipelines (e.g. for
tag-based deployments), create a **Project Access Token** with `write_repository` scope
and set it as `TOMSHLEY_CICD_FLOW_PUSH_TOKEN` in CI/CD variables (masked). The GitLab
adapter provides a default `TOMSHLEY_CICD_FLOW_PUSH_USER` of `oauth2`.

Bitbucket does not have this limitation — native pipeline pushes trigger pipelines by default.

### Variables

Set in **Settings > CI/CD > Variables** (all optional):

| Variable | Description |
|---|---|
| `TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX` | Prefix for merge/tag commit messages (default: `"Tomshley CI Pipeline"`) |
| `TOMSHLEY_CICD_FLOW_PUSH_TOKEN` | Token for flow push auth — enables pipeline triggering on GitLab (PAT with `write_repository`). Not needed on Bitbucket. |
| `TOMSHLEY_CICD_FLOW_PUSH_USER` | Username for flow push auth (GitLab adapter defaults to `oauth2`). Set on Bitbucket if using App Password. |

### Overriding Publish Extension Points

The `release-publish` and `hotfix-publish` jobs are intentional no-ops. Override them in your `.gitlab-ci.yml` to add project-specific publish logic:

    tomshley-cicd-flow-release-publish:
      extends:
        - .your-project-runtime
      stage: deploy
      script:
        - make push   # or sbt docker:publish, etc.

## Mirror Push

The adapter includes automated mirroring to a secondary remote (Bitbucket, GitHub, self-hosted, etc.).

### Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `TOMSHLEY_CICD_MIRROR_URL` | No | `""` | Remote URL (SSH or HTTPS). Empty = safe no-op. |
| `TOMSHLEY_CICD_MIRROR_BRANCHES` | No | `"main"` | Comma-separated branch list (same name on mirror) |
| `TOMSHLEY_CICD_MIRROR_BRANCH_MAP` | No | `""` | Comma-separated `src:dst` pairs for branch renaming. Overrides `BRANCHES` when set. |
| `TOMSHLEY_CICD_MIRROR_TAGS` | No | `"true"` | Mirror tags: `true` or `false` |
| `TOMSHLEY_CICD_MIRROR_SSH_KEY` | No | `""` | Path to SSH key in `.secure_files/` |
| `TOMSHLEY_CICD_MIRROR_FORCE_PUSH` | No | `"true"` | `true` = `--force`, `false` = `--force-with-lease` |

### Usage — Simple (no branch rename)

Set these as CI/CD variables (**Settings → CI/CD → Variables**):

| Variable | Value |
|---|---|
| `TOMSHLEY_CICD_MIRROR_URL` | `git@bitbucket.org:org/repo.git` |
| `TOMSHLEY_CICD_MIRROR_BRANCHES` | `main` |

### Usage — Branch Rename (develop → contrib)

| Variable | Value |
|---|---|
| `TOMSHLEY_CICD_MIRROR_URL` | `git@bitbucket.org:org/repo.git` |
| `TOMSHLEY_CICD_MIRROR_BRANCH_MAP` | `main:main,develop:contrib` |

### Usage — Multiple Remotes

Override the `tomshley-cicd-mirror-sync` job in your `.gitlab-ci.yml` to define one job per remote. GitLab runs them in parallel with independent failure handling:

    mirror-bitbucket:
      extends: .tomshley-cicd-mirror-config
      variables:
        TOMSHLEY_CICD_MIRROR_URL: "git@bitbucket.org:org/repo.git"
        TOMSHLEY_CICD_MIRROR_BRANCH_MAP: "main:main,develop:contrib"
        TOMSHLEY_CICD_MIRROR_SSH_KEY: ".secure_files/bitbucket_key"
      script:
        - bash /opt/tomshley-cicd-pipelines-toolbox/mirror/sync.sh

    mirror-github:
      extends: .tomshley-cicd-mirror-config
      variables:
        TOMSHLEY_CICD_MIRROR_URL: "git@github.com:org/repo.git"
        TOMSHLEY_CICD_MIRROR_BRANCHES: "main"
        TOMSHLEY_CICD_MIRROR_SSH_KEY: ".secure_files/github_key"
      script:
        - bash /opt/tomshley-cicd-pipelines-toolbox/mirror/sync.sh

### Behavior

- Runs in `.post` stage with `allow_failure: true` — mirror issues never block the main pipeline
- Skipped on merge request pipelines
- SSH key setup is automatic when `TOMSHLEY_CICD_MIRROR_SSH_KEY` is set (supports IPv6 hosts)
- Credentials are never logged — HTTPS URLs are sanitized before display

## Runner Images

All runners use Alpine 3.23 base with the toolbox baked in via `COPY --from=toolbox`.

| Image | Added tools |
|---|---|
| `cicd-toolbox` | Toolbox scripts only (not run directly — used as build stage) |
| `cicd-runner-sbtdockertofu` | JDK 21, SBT, Docker, Buildx, OpenTofu, Python 3 |
| `cicd-runner-sbtallure` | JDK 21, SBT, Docker, Buildx, Allure 2.30 |
| `cicd-runner-sbtrustdockertofu` | JDK 21, SBT, Rust 1.83, Zig, Docker, Buildx, OpenTofu, Python 3 |

## Container Registry Cleanup Policy (GitLab)

Configured in **Settings → Packages and registries → Container registry → Cleanup policies**:

| Setting | Value |
|---|---|
| Enable cleanup policy | Enabled |
| Run cleanup | Every day |
| Keep the most recent | 25 tags per image name |
| Keep tags matching | `^\d+\.\d+\.\d+$|^develop-latest$|^main-latest$` |
| Remove tags older than | 30 days |
| Remove tags matching | `.*` |

Notes:
- Semver release tags (for example `0.5.0`) are retained by regex.
- Rolling tags `develop-latest` and `main-latest` are retained.
- Branch/SHA tags are automatically cleaned after 30 days.

## Local Development

    make test               # Toolbox tests
    make build-load         # Build runner images locally
    make check              # Dry-run bake file

## Testing

- `toolbox/tests/` — Unit and integration tests for toolbox scripts
- `toolbox/tests/run-all.sh` — Runs all test suites
- Tests validate version parsing, gitflow lifecycle, pinned version drift, and variable documentation

## Versioning

- `VERSION` file is the release source of truth (SemVer)
- `release-start` and `hotfix-finish` auto-bump patch versions; major/minor bumps can be set manually before release
- Consumer projects should pin both template ref and runner tag to the same release (for example: `ref: 'v0.5.0'` and `CICD_PIPELINES_RUNNER_TAG: "0.5.0"`)
- Runner images are also tagged with `TOMSHLEY_CICD_BUILD_REVISION` for branch-specific testing

See [ROADMAP.md](ROADMAP.md) for planned milestones.

## License

Apache License 2.0 — see [LICENSE.md](LICENSE.md).
