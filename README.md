# cicd-pipelines

Spec-driven, multi-CI-platform templates and runner images for Tomshley projects.

## Architecture

    common/              Cross-platform specs + conformance tests (source of truth)
    ├── specs/           Machine-readable YAML contracts
    ├── tests/           Conformance + platform validators
    └── runners/scripts/ Shared CI/CD exports

    gitlab/              GitLab implementation
    ├── ci/              Hidden-job templates (.yml) — consumers include these
    ├── runners/         Dockerfile + scripts for runner images
    ├── docker-bake.hcl  BuildKit bake file
    └── Makefile         Build/push targets

    bitbucket/           Bitbucket implementation (in-development)
    ├── ci/              Placeholder for Bitbucket Pipelines templates
    └── runners/         Placeholder for runner images

## Naming Conventions

| Scope | Pattern | Example |
|---|---|---|
| Variables | `TOMSHLEY_CICD_{NAME}` | `TOMSHLEY_CICD_FLOW_TYPE` |
| GitLab hidden jobs | `.tomshley-cicd-{name}` | `.tomshley-cicd-debug` |
| GitLab flow jobs | `tomshley-cicd-flow-{lifecycle}` | `tomshley-cicd-flow-release-start` |
| Runner images | `cicd-gitlab-runner-{name}` | `cicd-gitlab-runner-sbtdockertofu` |

## Consumer Usage (GitLab)

In your project's `.gitlab-ci.yml`:

    include:
      - project: 'tomshley/brands/global/tware/tech/products/provisioning/cicd-pipelines'
        ref: 'v0.4.0'
        file:
          - '/gitlab/ci/.stages-base.yml'
          - '/gitlab/ci/.gitflow-base.yml'
          - '/gitlab/ci/.gitflow-branch-policy.yml'
          - '/gitlab/ci/.gitflow-jobs.yml'
          - '/gitlab/ci/.container-tags.yml'
          - '/gitlab/ci/.artifact-publish-policy.yml'
          - '/gitlab/ci/.security-scanning.yml'
          - '/gitlab/ci/.sbt-runtime.yml'            # pick the runtime you need
          - '/gitlab/ci/.sbt-docker-publish.yml'      # add if you publish docker images
          - '/gitlab/ci/.docker-runtime.yml'           # add if you build containers

## Git Flow Lifecycle Jobs

Including `.gitflow-jobs.yml` gives your project automated gitflow lifecycle management:

| Job | Stage | Trigger | Action |
|---|---|---|---|
| `tomshley-cicd-flow-release-start` | `.post` | Manual on `develop` | Creates `release/*` branch, bumps VERSION |
| `tomshley-cicd-flow-release-publish` | `deploy` | Manual on `release/*` | No-op extension point (override to publish RCs) |
| `tomshley-cicd-flow-release-finish` | `.post` | Manual on `release/*` | Merges to main + develop, tags, deletes branch |
| `tomshley-cicd-flow-hotfix-publish` | `deploy` | Manual on `hotfix/*` | No-op extension point (override to publish hotfix artifacts) |
| `tomshley-cicd-flow-hotfix-finish` | `.post` | Manual on `hotfix/*` | Bumps VERSION, merges to main + develop, tags, deletes branch |

### Prerequisites

The gitflow finish jobs (`release-finish`, `hotfix-finish`) push branches and tags to the repository.
You must grant write access by **one** of these methods:

1. **CI_JOB_TOKEN (recommended):** Go to **Settings → CI/CD → Token permissions** and enable **"Allow CI/CD job tokens to push to this project's repository"**. No variables needed.
2. **Dedicated token:** Create a Project Access Token with `write_repository` scope and set `TOMSHLEY_CICD_GIT_PUSH_TOKEN` as a masked CI/CD variable.

### Variables

Set in **Settings > CI/CD > Variables**:

| Variable | Required | Description |
|---|---|---|
| `TOMSHLEY_CICD_GIT_PUSH_TOKEN` | Optional | Access token with `write_repository` scope (masked). Not needed if using CI_JOB_TOKEN push access. |
| `TOMSHLEY_CICD_GIT_PUSH_USER` | Optional | Username for git push (defaults to `GITLAB_USER_LOGIN`) |
| `TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX` | Optional | Prefix for merge/tag commit messages (default: `"Tomshley CI Pipeline"`) |

Fallback chain: `TOMSHLEY_CICD_GIT_PUSH_TOKEN` → `GL_PASSWORD` → `CI_JOB_TOKEN`

### Overriding Publish Extension Points

The `release-publish` and `hotfix-publish` jobs are intentional no-ops. Override them in your `.gitlab-ci.yml` to add project-specific publish logic:

    tomshley-cicd-flow-release-publish:
      extends:
        - .your-project-runtime
      stage: deploy
      script:
        - make push   # or sbt docker:publish, etc.

## Pipeline Categories

| Category | Templates composed | Runner |
|---|---|---|
| sbt-docker | stages + gitflow + sbt-runtime + docker-runtime + publish + security | sbtdockertofu |
| sbt | stages + gitflow + sbt-runtime + publish + security | sbtdockertofu |
| terraform | stages + gitflow + terraform-runtime + security | sbtdockertofu (interim) |
| container | stages + gitflow + docker-runtime + container-tags + publish + security | Stock DinD |

## Runner Images

| Image | Base | Added tools |
|---|---|---|
| `cicd-gitlab-runner-base` | Alpine 3.23 | curl, jq, make, openssh, git, gcompat |
| `cicd-gitlab-runner-scripts` | runner-base | 24 CI/CD shell scripts |
| `cicd-gitlab-runner-sbtdockertofu` | runner-base + scripts | JDK 21, SBT, Docker, Buildx, OpenTofu, Python 3 |

## Local Development

    make test               # Conformance tests
    make gitlab-build-load  # Build runner images locally
    make gitlab-check       # Dry-run bake file

## Conformance Model

- `common/specs/` defines contracts for stages, flow types, publish policy, etc.
- `common/tests/conformance.sh` validates all active/in-development platforms
- `active` platforms → failures are errors
- `in-development` platforms → failures are warnings
- `roadmap` platforms → skipped

## Versioning

- Version in `VERSION` file (currently `v0.4.0`)
- Consumer projects pin to `ref: 'v0.4.0'` in their includes
- Runner images tagged with `TOMSHLEY_CICD_BUILD_REVISION`

See [ROADMAP.md](ROADMAP.md) for planned milestones.

## License

Apache License 2.0 — see [LICENSE.md](LICENSE.md).
