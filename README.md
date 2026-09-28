# cicd-pipelines

Spec-driven, multi-CI-platform templates and runner images for Tomshley projects.

## Architecture

    toolbox/                      Platform-agnostic shell scripts (OCI image)
    ├── scripts/                  Gitflow, mirror, secrets, platform abstraction
    │   ├── flow/                 Release / hotfix lifecycle
    │   ├── mirror/               Push and poll mirroring
    │   ├── platform/             Sourced entry points (toolbox-entry, publish-policy)
    │   ├── publish/              Publish recipes (generic, sbt, npm, python, cargo, release assets)
    │   ├── build/                Build recipes (cargo cross-compilation)
    │   ├── verify/               Fail-closed guards (tag/VERSION, WebJar pairing, image tag)
    │   ├── retention/            Scheduled package retention
    │   ├── lib/                  Shared helpers (sourced by scripts only)
    │   └── secrets/              Pluggable secret delivery (gitlab, delinea, etc.)
    ├── tests/                    Unit + integration tests
    ├── Dockerfile                Toolbox OCI image (COPY'd into runners)
    └── VARIABLES.md              Environment variable documentation

    runners/                      Build environment images (toolbox baked in)
    ├── sbtdockertofu/            Scala + Docker + OpenTofu runner (flow image)
    ├── sbtallure/                Scala + Allure test reporting runner
    ├── sbtrustdockertofu/        Scala + Rust/Zig cross-compilation + Docker + OpenTofu runner
    ├── pythondocker/             Python + pip + Docker runner
    ├── awsdockertofu/            AWS CLI + Docker + OpenTofu runner
    └── tofu/                     Provider-neutral OpenTofu runner

    adapters/                     Platform-specific YAML templates
    ├── gitlab/ci/adapter.yml     GitLab CI adapter (all stages, jobs, policies)
    └── bitbucket/ci/adapter.yml  Bitbucket Pipelines adapter

    tools/                        Maintainer tools (not shipped in the toolbox image)
    └── ci-lint-local.py          Lint consumer pipelines against the working-tree adapter

    docker-bake.hcl               BuildKit bake file (toolbox + runners)
    Makefile                      Build/test/push targets

Layering: base-containers owns toolchains (entry images such as `entry-rust`,
`entry-zig`, `entry-sbt`); this repository composes them into runner images and
ships pipeline logic. Adapters never pull third-party images or install
toolchains at job time — a toolchain change is a base-containers bump followed by
a runner rebuild.

Entry images provide reusable tools; use-case images provide application runtime foundations. Runner images are CI build, test, and publication environments and include the toolbox. The Rust runner uses a rustup-managed compiler for cross-target installation; its Rust version must match the copied entry toolchain. Application runtime images do not inherit this runner.

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
        ref: 'v0.11.0'
        file: '/adapters/gitlab/ci/adapter.yml'

    variables:
      CICD_PIPELINES_RUNNER_TAG: "0.11.0"   # pin to runner image version (match your ref)

When self-hosting this repository across a runner-image change, `CICD_PIPELINES_RUNNER_TAG`
in this repo's `.gitlab-ci.yml` must name an already published tag, so the release pipeline
can build and publish the new images. A published `develop-*` tag is a valid stand-in.

## Secrets Bootstrap

The adapters provide a consumer-overridable secrets bootstrap mechanism before `toolbox-entry.sh` runs. GitLab downloads Secure Files into `.secure_files/` by default. Bitbucket runs a same-position bootstrap hook via `secrets/bitbucket-bootstrap.sh`; the default Bitbucket hook is a no-op placeholder that consumers replace with their own provider.

### How it works

1. GitLab: `.tomshley-cicd-secure-files` uses `secrets/gitlab-secure-files.sh` when the toolbox is present, and falls back to the GitLab installer in non-toolbox images
2. Bitbucket: `&toolbox-setup` runs `secrets/bitbucket-bootstrap.sh` before `toolbox-entry.sh`; consumers replace that hook with their own provider when needed
3. The provider contract is always the same: populate `.secure_files/` before `toolbox-entry.sh` runs
4. `toolbox-entry.sh` sources `.secure_files/.env` to export secrets as environment variables

On GitLab, secrets bootstrap runs by default in toolbox-based job chains: `.tomshley-cicd-bootstrap`, `.tomshley-cicd-git-push-config`, `.tomshley-cicd-mirror-config`. It is **not** added to `.before-artifact-tags` because that fragment feeds into `.tomshley-docker-runtime`, which uses base-containers images without the toolbox. On Bitbucket, the bootstrap hook runs in the shared `&toolbox-setup` anchor before every toolbox step.

### Opt-out

Set `TOMSHLEY_CICD_SECRETS_BOOTSTRAP` to `"false"` per-job or project-wide:

    variables:
      TOMSHLEY_CICD_SECRETS_BOOTSTRAP: "false"

### Override with a different provider

Consumers can override the default provider to use Delinea, Vault, or any other provider. The only contract is: populate `.secure_files/` before `toolbox-entry.sh` runs.

GitLab:

    .tomshley-cicd-secure-files:
      before_script:
        - "${TOMSHLEY_CICD_TOOLBOX_ROOT}/secrets/delinea.sh"

Bitbucket:

    definitions:
      yaml-anchors:
        - &toolbox-bootstrap |
            export TOMSHLEY_CICD_TOOLBOX_ROOT="${TOMSHLEY_CICD_TOOLBOX_ROOT:-/opt/tomshley-cicd-pipelines-toolbox}"
            "${TOMSHLEY_CICD_TOOLBOX_ROOT}/secrets/delinea.sh"
            source "${TOMSHLEY_CICD_TOOLBOX_ROOT}/platform/toolbox-entry.sh"
            if [ -f "${TOMSHLEY_CICD_PROJECT_DIR}/VERSION" ]; then
              export TOMSHLEY_CICD_BUILD_VERSION="$(cat "${TOMSHLEY_CICD_PROJECT_DIR}/VERSION")"
            else
              export TOMSHLEY_CICD_BUILD_VERSION="dev"
            fi
            echo "Build Version   : ${TOMSHLEY_CICD_BUILD_VERSION}"

Available toolbox scripts:
- `secrets/gitlab-secure-files.sh` — GitLab Secure Files (default)
- `secrets/bitbucket-bootstrap.sh` — Bitbucket pre-`toolbox-entry.sh` hook (default no-op)
- `secrets/delinea.sh` — Delinea (placeholder, not yet implemented)

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
| `TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX` | Prefix for all flow-generated commit/merge/tag messages (default: `""`, no prefix) |
| `TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_PATTERN` | Regex to auto-derive the prefix from recent commit subjects when `FLOW_MESSAGE_PREFIX` is unset (e.g. an issue-tracker key pattern like `PROJ-[0-9]+`) |
| `TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER` | Marker appended to develop merge messages (default: `[skip ci]`; set empty to disable) |
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

## Publish Recipes

Hidden job templates publish artifacts under the artifact policy — pinnable
`{ref-slug}-{sha}` and rolling `{ref-slug}-latest` on branches, the clean version
on tags — and refuse to publish a tag whose version differs from `VERSION`.
Each recipe is a toolbox script; the adapter only maps GitLab variables and
selects a house runner image.

| Template | Publishes | Consumer inputs |
|---|---|---|
| `.tomshley-cicd-publish-generic` | One file to the generic package registry, once per label | `TOMSHLEY_CICD_GENERIC_PACKAGE`, `TOMSHLEY_CICD_GENERIC_ARTIFACT` |
| `.tomshley-cicd-publish-sbt` | `sbt publish` with `TOMSHLEY_CICD_BUILD_REVISION` set from the policy | override `script` for multi-module builds |
| `.tomshley-cicd-publish-npm` | One prerelease version per branch build, rolling dist-tag `{ref-slug}-latest`; clean version on tags | `package.json` version |
| `.tomshley-cicd-publish-python` | Pinnable then rolling build; the build composes the PEP 440 version from `TOMSHLEY_CICD_BUILD_CHANNEL` + `TOMSHLEY_CICD_BUILD_REVISION` | `TOMSHLEY_CICD_PYPI_PACKAGE` |
| `.tomshley-cicd-cargo-zigbuild` | Cross-compiles every target with cargo-zigbuild on `cicd-runner-sbtrustdockertofu` | `TOMSHLEY_CICD_CARGO_TARGETS`, `TOMSHLEY_CICD_CARGO_BINARY`, optional `TOMSHLEY_CICD_CARGO_NATIVE_ROOT` |
| `.tomshley-cicd-publish-cargo` | Every binary as `<binary>-<platform>[.exe]` to the generic registry | same targets + binary |
| `.tomshley-cicd-release-assets` | Tag pipelines only: binaries (+ `SHA256SUMS`) uploaded and linked from a release | same, optional `TOMSHLEY_CICD_RELEASE_CHECKSUM_FILE` |
| `.tomshley-cicd-package-retention` | Scheduled pipelines only: deletes pinnable packages older than `TOMSHLEY_CICD_RETENTION_DAYS` (default 30); release and rolling versions are kept | optional `TOMSHLEY_CICD_RETENTION_DAYS` |

Fragments for consumer `before_script` chains: `.tomshley-cicd-tag-version-guard`,
`.tomshley-cicd-webjar-pairing` (project `<version>` must equal
`<properties><upstreamVersion>`), and `.tomshley-cicd-image-tag-guard` (see
"Image publication preflight").

    publish:
      extends: [.tomshley-cicd-publish-generic]
      needs: [package]
      variables:
        TOMSHLEY_CICD_GENERIC_PACKAGE: my-spec
        TOMSHLEY_CICD_GENERIC_ARTIFACT: my-spec.tar.gz

    publish-maven:
      extends: [.tomshley-cicd-publish-sbt]
      script:
        - bash "${TOMSHLEY_CICD_TOOLBOX_ROOT}/publish/sbt.sh" sbt +core/publish +plugin/publish

Registry auth defaults to the job token. Deleting packages (Python rolling
cleanup, retention) usually needs more; set `TOMSHLEY_CICD_PACKAGE_TOKEN` as a
masked variable for those jobs. All inputs are documented in
`toolbox/VARIABLES.md` under "Publish Recipe Variables".

### Image publication preflight

`verify/image-tag-guard.sh` is CI-independent: it runs from any CI — or
locally — with only a POSIX shell, `curl`, and `jq`. The caller supplies
the fully-qualified image repository (registry host and repository path,
no tag or digest) in `TOMSHLEY_CICD_REGISTRY_IMAGE` — Docker Hub
shorthand is not normalized — and the event tag in `TOMSHLEY_CICD_TAG`;
the checked version defaults to the tag minus a leading `v` and can be
overridden with `CICD_PUBLISH_VERSION`. An empty tag (branch pipeline)
is a no-op that exits before `curl` or `jq` is required; a missing image
on a tag pipeline fails.

Registry authentication belongs to the caller. When
`TOMSHLEY_CICD_REGISTRY_AUTH_FILE` names a file containing an OCI
`Authorization:` header line, the guard forwards it to `curl` by path —
never as a command argument — and a missing or empty file fails the
check. Without the file the probe is anonymous. The guard never runs
`docker login`, reads no Docker client configuration, and does not
emulate credential helpers.

The check issues a read-only `GET /v2/<repository>/manifests/<tag>`
request over HTTPS — never plain HTTP, never a redirect, TLS always
verified — with a 15 second connect timeout, a 30 second overall limit,
and a 1 MiB response cap. An HTTP 200 (a manifest or a manifest index)
refuses publication; an HTTP 404 permits the push only when the body is a
single JSON object whose non-empty `errors` array contains exclusively
`MANIFEST_UNKNOWN` or `NAME_UNKNOWN` codes — a proxy's generic 404 page
does not count. Anything else — authentication, network, TLS, or
rate-limit failures and malformed or mixed responses — fails closed.
Invoke it immediately before the push, inside the publish job or step,
not as a separate job.

The guard observes registry state at one moment and does not reserve a tag.
Only registry-side immutable-tag enforcement can prevent two simultaneous
writers from racing the check; configure that policy in the registry — the
toolkit changes none.

GitLab (`!reference` inside `script` runs the check between build and push;
the base `.tomshley-docker-runtime` image has no toolbox, so the job runs on
a runner image that carries it — the runtime's `before_script` still logs
into the project registry). The fragment needs `curl` and `jq`, which the
toolbox runner images already provide. When the image's registry host
equals `CI_REGISTRY` (the instance container registry) and no auth file is
given, the fragment exchanges the existing
`CI_REGISTRY_USER`/`CI_REGISTRY_PASSWORD` job credentials for a
`repository:<image>:pull` bearer token at `${CI_SERVER_URL}/jwt/auth` and
hands the guard that header file; the job token can always read its own
project's repository, and a repository it cannot read fails closed. An
explicit `TOMSHLEY_CICD_REGISTRY_AUTH_FILE` always wins, and other
registries always use the caller's file:

    publish:docker:
      extends: .tomshley-docker-runtime
      image: ${CICD_PIPELINES_FLOW_IMAGE}
      variables:
        TOMSHLEY_CICD_REGISTRY_IMAGE: "$CI_REGISTRY_IMAGE/image"
      script:
        - docker build -t "${TOMSHLEY_CICD_REGISTRY_IMAGE}:${CICD_PUBLISH_VERSION}" .
        - !reference [.tomshley-cicd-image-tag-guard, before_script]
        - docker push "${TOMSHLEY_CICD_REGISTRY_IMAGE}:${CICD_PUBLISH_VERSION}"
      rules:
        - if: '$CI_COMMIT_TAG'
          when: manual

Bitbucket (merge into the copied adapter alongside the existing
`pipelines.custom` entries; it uses the adapter's toolbox/Docker flow
image). Supply push credentials through the consumer's existing credential
delivery. Separately, set `TOMSHLEY_CICD_REGISTRY_AUTH_FILE` to a protected
file containing the registry's pull authorization header, prepared by that
registry's authentication flow. A Docker login password is not necessarily
an OCI bearer token. The guard consumes the header file without copying it
into the repository:

    pipelines:
      tags:
        'v*':
          - step:
              name: "Publish Image"
              services: [docker]
              script:
                - *toolbox-core-env
                - export TOMSHLEY_CICD_REGISTRY_IMAGE="registry.example.com/group/project/image"
                - test -s "${TOMSHLEY_CICD_REGISTRY_AUTH_FILE:?registry pull authorization file required}"
                - printf '%s' "$PUBLISH_REGISTRY_TOKEN" | docker login registry.example.com --username "$PUBLISH_REGISTRY_USER" --password-stdin
                - . "${TOMSHLEY_CICD_TOOLBOX_ROOT}/platform/publish-policy.sh"
                - docker build -t "${TOMSHLEY_CICD_REGISTRY_IMAGE}:${CICD_PUBLISH_VERSION}" .
                - *image-tag-guard
                - docker push "${TOMSHLEY_CICD_REGISTRY_IMAGE}:${CICD_PUBLISH_VERSION}"

Any CI or local caller can invoke the helper directly with explicit portable
variables:

    TOMSHLEY_CICD_TAG="v1.2.3" \
    TOMSHLEY_CICD_REGISTRY_IMAGE="registry.example.com/group/project/image" \
    sh /opt/tomshley-cicd-pipelines-toolbox/verify/image-tag-guard.sh

### Linting a consumer against the working-tree adapter

    GITLAB_TOKEN=... python3 tools/ci-lint-local.py adapters/gitlab/ci/adapter.yml \
      --project-id <consumer project id> ../consumer/.gitlab-ci.yml

## Security Scans on Tag Pipelines (GitLab)

Upstream analyzer rules match branch and merge-request pipelines only, so the
adapter adds tag-only twins for the five pre-build analyzers it covers:
`secret_detection`, `semgrep-sast`, and the three Gemnasium dependency
scanners (`gemnasium`, `gemnasium-maven`, `gemnasium-python`). Each twin
`extends` its analyzer — script, image, stage, and `allow_failure` policy
stay upstream's — and re-adds the analyzer's own conditions scoped to
`$CI_COMMIT_TAG`: disable switches (`*_DISABLED`), exclusion lists
(`*_EXCLUDED_ANALYZERS`), dependency-scanning license gating
(`GITLAB_FEATURES`), file detection (`exists:` references to the upstream
shared rules), and the FIPS image suffix (`CI_GITLAB_FIPS_MODE` →
`DS_IMAGE_SUFFIX: "-fips"`), including the custom `PIP_REQUIREMENTS_FILE`
variant for `gemnasium-python`.

`semgrep-sast-tag` scans every Semgrep-supported file. GitLab Advanced SAST
has no tag twin, so upstream's branch-pipeline hand-off of overlapping
languages to Advanced SAST (its `sast_advanced` rules) is intentionally not
reproduced on tags.

`secret_detection-tag` also sets `GIT_DEPTH: "0"` (full clone) and
`SECRET_DETECTION_LOG_OPTIONS: "$CI_COMMIT_SHA"` so the scan covers the full
reachable history ending at the tagged commit rather than the default
last-commit-only comparison.

The twins keep the upstream `allow_failure` policy, so tag scans surface
reports without turning into a release-blocking gate. Other upstream
analyzers keep their own scheduling — the adapter does not newly enable the
optional or advanced analyzers. These are GitLab-native integrations; this
change does not add scanners to Bitbucket.

## Mirror Push

The adapter includes automated mirroring to a secondary remote (Bitbucket, GitHub, self-hosted, etc.).

### Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `TOMSHLEY_CICD_MIRROR_URL` | No | `""` | Remote URL (SSH or HTTPS). Empty = safe no-op. |
| `TOMSHLEY_CICD_MIRROR_BRANCHES` | No | `"main"` | Comma-separated branch list (same name on mirror) |
| `TOMSHLEY_CICD_MIRROR_BRANCH_MAP` | No | `""` | Comma-separated `src:dst` pairs for branch renaming. Identity glob patterns supported (e.g. `contrib/*:contrib/*`); rename/asymmetric glob patterns are refused. Overrides `BRANCHES` when set. See `toolbox/VARIABLES.md`. |
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
        - bash "${TOMSHLEY_CICD_TOOLBOX_ROOT}/mirror/sync.sh"

    mirror-github:
      extends: .tomshley-cicd-mirror-config
      variables:
        TOMSHLEY_CICD_MIRROR_URL: "git@github.com:org/repo.git"
        TOMSHLEY_CICD_MIRROR_BRANCHES: "main"
        TOMSHLEY_CICD_MIRROR_SSH_KEY: ".secure_files/github_key"
      script:
        - bash "${TOMSHLEY_CICD_TOOLBOX_ROOT}/mirror/sync.sh"

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
| `cicd-runner-sbtrustdockertofu` | JDK 21, SBT, Rust 1.98.1 (rustup + Linux GNU/musl, Darwin, and Windows targets, cargo-zigbuild 0.23.3), Zig 0.16.0, Docker, Buildx, OpenTofu, Python 3 |
| `cicd-runner-pythondocker` | Python 3, pip, Docker, Buildx |
| `cicd-runner-awsdockertofu` | AWS CLI, Python 3, Docker, Buildx, OpenTofu |
| `cicd-runner-tofu` | OpenTofu, git, git-flow, make, jq — no cloud CLI, no Docker |

The Rust runner pins cargo-zigbuild 0.23.3 because 0.23.4 breaks Darwin exported-symbols list handling with Zig 0.16. Track the [upstream linker regression](https://github.com/rust-cross/cargo-zigbuild/issues/479) before upgrading this pin.

No runner ships Node.js yet; `.tomshley-cicd-publish-npm` installs `nodejs npm`
from Alpine at job start when the image lacks them (the same fallback the
ensure-tools fragment uses for git/curl). A dedicated polyglot runner is on the
roadmap.

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

The toolbox tests need `bash`, `git`, GNU `grep`, `gawk`, `jq`, and
`python3` — the packages the `toolbox-tests` job installs. Publish and
guard tests run against a fake `curl`, so they need no Docker daemon,
external registry, or production credentials.

- `toolbox/tests/` — Unit and integration tests for toolbox scripts
- `toolbox/tests/run-all.sh` — Runs all test suites
- Tests validate version parsing, gitflow lifecycle, pinned version drift, and variable documentation

## Versioning

- `VERSION` file is the release source of truth (SemVer)
- `release-start` and `hotfix-finish` auto-bump patch versions; major/minor bumps can be set manually before release
- Consumer projects should pin both template ref and runner tag to the same release (for example: `ref: 'v0.11.0'` and `CICD_PIPELINES_RUNNER_TAG: "0.11.0"`)
- Runner images are also tagged with `TOMSHLEY_CICD_BUILD_REVISION` for branch-specific testing

See [ROADMAP.md](ROADMAP.md) for planned milestones.

## License

Apache License 2.0 — see [LICENSE.md](LICENSE.md).
