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
| Runner images | `cicd-gitlab-runner-{name}` | `cicd-gitlab-runner-sbtdockertofu` |

## Consumer Usage (GitLab)

In your project's `.gitlab-ci.yml`:

    include:
      - project: 'tomshley/brands/global/tware/tech/products/provisioning/cicd-pipelines'
        ref: 'v0.0.1'
        file:
          - gitlab/ci/.stages-base.yml
          - gitlab/ci/.gitflow-base.yml
          - gitlab/ci/.gitflow-branch-policy.yml
          - gitlab/ci/.gitflow-jobs.yml
          - gitlab/ci/.artifact-publish-policy.yml
          - gitlab/ci/.security-scanning.yml
          - gitlab/ci/.sbt-runtime.yml        # pick the runtime you need
          - gitlab/ci/.docker-runtime.yml      # add if you build containers

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

- Version in `VERSION` file (currently `0.0.1`)
- Consumer projects pin to `ref: 'v0.0.1'` in their includes
- Runner images tagged with `TOMSHLEY_CICD_BUILD_REVISION`

See [ROADMAP.md](ROADMAP.md) for planned milestones.

## License

Apache License 2.0 — see [LICENSE.md](LICENSE.md).
