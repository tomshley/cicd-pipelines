# Toolbox Environment Variables

Reference for consumers of the cicd-pipelines toolbox.

Variables are organized by who sets them and where they are used.

---

## Consumer Variables (you set these)

### Secrets Bootstrap Variables (used by `secrets/*.sh`)

| Variable | Required? | Default | Description |
|----------|-----------|---------|-------------|
| `TOMSHLEY_CICD_SECRETS_BOOTSTRAP` | No | `"true"` | Set to `"false"` to skip secrets bootstrap (per-job or project-wide). On GitLab, the default provider downloads Secure Files. On Bitbucket, the default pre-`toolbox-entry.sh` hook is a no-op placeholder. In both adapters, the provider contract is the same: populate `.secure_files/` before `toolbox-entry.sh` sources `.secure_files/.env`. |

### Flow Variables (used by `flow/*.sh`)

| Variable | Required? | Default | Description |
|----------|-----------|---------|-------------|
| `TOMSHLEY_CICD_GIT_USER_EMAIL` | No | platform-specific | Git commit author email (GitLab: `GITLAB_USER_EMAIL`, Bitbucket: `pipeline@noreply.bitbucket.org`) |
| `TOMSHLEY_CICD_GIT_USER_NAME` | No | platform-specific | Git commit author display name (GitLab: `GITLAB_USER_NAME`, Bitbucket: `"Bitbucket Pipeline"`) |
| `TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX` | No | `""` (no prefix) | Prefix for all flow-generated commit/merge/tag messages (version bumps, `release-continue` develop-merges, and finish merges/tags). When set, prepended with a trailing space, e.g. `"JIRA-123:"` produces `"JIRA-123: chore: bump version to 1.2.3"`. |
| `TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_PATTERN` | No | (unset) | POSIX extended regex used to **derive** the prefix when `FLOW_MESSAGE_PREFIX` is unset: recent commit subjects on the checked-out branch are scanned and the first match becomes the prefix. Useful to propagate an issue-tracker key already present in the branch history (e.g. `PROJ-[0-9]+` or `#[0-9]+`) into flow-generated messages without hardcoding a key — for example to satisfy a commit-message verification rule. No match ⇒ no prefix (with a warning). Note: the scan includes flow-generated commits themselves, so with a shallow scan window the first match may come from an earlier release's bump/merge commit — tune `SCAN_DEPTH` or set the explicit prefix if exact issue attribution matters. |
| `TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX_SCAN_DEPTH` | No | `20` | Number of recent commit subjects scanned by `FLOW_MESSAGE_PREFIX_PATTERN`. |
| `TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER` | No | `"[skip ci]"` | Marker appended to develop merge messages. Set to an empty string to disable (no marker, no trailing separator). |
| `TOMSHLEY_CICD_FLOW_PUSH_TOKEN` | No | (unset) | Token for flow git push auth (GitLab PAT, Bitbucket App Password, GitHub PAT). When set with `FLOW_PUSH_USER`, overrides native CI clone URL credentials. Enables pipeline triggering on GitLab. |
| `TOMSHLEY_CICD_FLOW_PUSH_USER` | No | platform-specific | Username for flow git push auth (GitLab adapter: `oauth2`). Only used when `FLOW_PUSH_TOKEN` is also set. |

### Mirror Variables (used by `mirror/sync.sh`)

| Variable | Required? | Default | Description |
|----------|-----------|---------|-------------|
| `TOMSHLEY_CICD_MIRROR_URL` | No | `""` (empty = no-op) | Remote URL (SSH or HTTPS). Leave empty to disable mirroring. |
| `TOMSHLEY_CICD_MIRROR_BRANCHES` | No | `"main"` | Comma-separated branch list |
| `TOMSHLEY_CICD_MIRROR_BRANCH_MAP` | No | `""` | Comma-separated `src:dst` pairs. Supports glob patterns (e.g., `"develop-*:develop-*"`). Overrides BRANCHES when set. |
| `TOMSHLEY_CICD_MIRROR_TAGS` | No | `"true"` | Mirror tags: `true` or `false` |
| `TOMSHLEY_CICD_MIRROR_SSH_KEY` | No | `""` | Path to SSH key file (e.g. in `.secure_files/`) |
| `TOMSHLEY_CICD_MIRROR_FORCE_PUSH` | No | `"true"` | `true` = `--force`, `false` = `--force-with-lease` |

### Publish Recipe Variables

Recipes live under `publish/`, `build/`, `verify/`, and `retention/`. Each resolves
the artifact policy (`platform/publish-policy.sh`), enforces the tag/VERSION guard,
and then publishes. Consumers set the inputs below as job variables; the adapter
supplies registry endpoints and credentials (see "Adapter-Mapped Variables").

**Consumer inputs (you set these)**

| Variable | Used by | Required? | Default | Description |
|----------|---------|-----------|---------|-------------|
| `TOMSHLEY_CICD_GENERIC_PACKAGE` | `publish/generic.sh` | Yes | — | Package name in the generic registry. Uploaded file is `<package>-<label>.<artifact extension>`. |
| `TOMSHLEY_CICD_GENERIC_ARTIFACT` | `publish/generic.sh` | Yes | — | Path of the file to upload (built earlier in the job or fetched as a job artifact). |
| `TOMSHLEY_CICD_PYPI_PACKAGE` | `publish/python.sh` | Yes | — | Distribution name exactly as the registry lists it; used to delete the previous rolling upload before re-publishing. |
| `TOMSHLEY_CICD_CARGO_TARGETS` | `build/cargo-zigbuild.sh`, `publish/cargo.sh`, `publish/release-assets.sh` | Yes | — | Space-separated Rust target triples. Supported: `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu`, `x86_64-unknown-linux-musl`, `aarch64-unknown-linux-musl`, `x86_64-apple-darwin`, `aarch64-apple-darwin`, `x86_64-pc-windows-gnu` (see `lib/rust-targets.sh`). |
| `TOMSHLEY_CICD_CARGO_BINARY` | same three | Yes | — | Binary name the crate produces; also the generic package name. Published as `<binary>-<platform>[.exe]`. |
| `TOMSHLEY_CICD_CARGO_NATIVE_ROOT` | `build/cargo-zigbuild.sh` | No | (unset = skip) | Directory receiving `<platform>/<binary>` copies plus `manifest.json` of SHA-256 digests — for embedding native binaries as resources. |
| `TOMSHLEY_CICD_CARGO_CHECKSUM_FILE` | `build/cargo-zigbuild.sh` | No | `SHA256SUMS` | Where `sha256sum` output for the native resources is written. |
| `TOMSHLEY_CICD_RELEASE_CHECKSUM_FILE` | `publish/release-assets.sh` | No | (unset) | Checksum file attached to the release as `SHA256SUMS`. |
| `TOMSHLEY_CICD_WEBJAR_POM` | `verify/webjar-pairing.sh` | No | `pom.xml` | POM whose project `<version>` must equal `<properties><upstreamVersion>`. |
| `TOMSHLEY_CICD_RETENTION_DAYS` | `retention/package-retention.sh` | No | `30` | Age after which pinnable build packages are deleted. Release versions (digits and dots) and rolling versions (ending in `latest`) are always kept — the same rule as the container registry cleanup policy. |
| `TOMSHLEY_CICD_PUBLISH_PROJECT_ID` | consumer build definitions | No | — | Passed through untouched for build tools that publish to a project-scoped registry (for example an sbt setting reading it). No toolbox script consumes it. |

**Exported to the build by recipes (do NOT set manually)**

| Variable | Set by | Value |
|----------|--------|-------|
| `TOMSHLEY_CICD_BUILD_REVISION` | `publish/sbt.sh`, `publish/python.sh` | `$CICD_PUBLISH_PINNABLE_TAG` / `$CICD_PUBLISH_ROLLING_TAG` for the channel being built; empty on tag pipelines so the build publishes its clean version. |
| `TOMSHLEY_CICD_BUILD_CHANNEL` | `publish/python.sh` | `tag`, `pinnable`, or `rolling` — the Python build composes a PEP 440 version from this and the revision. |
| `CICD_PUBLISH_*` | `platform/publish-policy.sh` | See "Artifact Tags" in the GitLab adapter: `PINNABLE`, `ROLLING`, `PINNABLE_TAG`, `ROLLING_TAG`, `VERSION`, `LABELS`. |

### Mirror Poll Variables (used by `mirror/poll-remote.sh`)

For cron/scheduled-driven reverse mirroring. `poll-remote.sh` fetches a remote
and pushes matching branches to local origin. Loop-safe when forward
(`MIRROR_BRANCHES`) and reverse (`MIRROR_POLL_BRANCH_PATTERNS`) sets are
disjoint.

| Variable | Required? | Default | Description |
|----------|-----------|---------|-------------|
| `TOMSHLEY_CICD_MIRROR_POLL_URL` | Yes (for poll) | `""` | Remote URL to fetch FROM (the "external" mirror) |
| `TOMSHLEY_CICD_MIRROR_POLL_BRANCH_PATTERNS` | Yes (for poll) | `""` | Comma-separated glob patterns. Example: `"develop-*,oss/*"` |
| `TOMSHLEY_CICD_MIRROR_POLL_PUSH_TOKEN` | No | `""` | Token for pushing to local origin (GitLab PAT, Bitbucket App Password) |
| `TOMSHLEY_CICD_MIRROR_POLL_PUSH_USER` | No | platform-specific | Username for HTTPS push auth (GitLab: `oauth2`, Bitbucket: `x-token-auth`) |
| `TOMSHLEY_CICD_MIRROR_POLL_SSH_KEY` | No | `""` | SSH key path for fetching from poll URL |
| `TOMSHLEY_CICD_MIRROR_POLL_DRY_RUN` | No | `false` | Skip actual push for testing |
| `TOMSHLEY_CICD_MIRROR_POLL_FORCE_PUSH` | No | `false` | `true` = `--force`, `false` = `--force-with-lease` |

---

## Deployment Recipes

### Recipe A: Read-Only Mirror (current pattern)

GitLab is source-of-truth; Bitbucket is read-only mirror. Tags + main + develop sync forward.

**GitLab `.gitlab-ci.yml`:**
```yaml
tomshley-cicd-mirror-sync:
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
  variables:
    TOMSHLEY_CICD_MIRROR_URL: "git@bitbucket.org:org/repo.git"
    TOMSHLEY_CICD_MIRROR_BRANCHES: "main,develop"
    TOMSHLEY_CICD_MIRROR_TAGS: "true"
```

### Recipe B: External Contribution (push-driven, bidirectional)

External contributors push `develop-*` branches on the secondary platform (e.g., Bitbucket). Maintainers review and merge them to `develop` on the primary platform (e.g., GitLab) via merge request.

**GitLab `.gitlab-ci.yml`** (forward mirror — main/develop only):
```yaml
tomshley-cicd-mirror-sync:
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^(main|develop)$/'
  variables:
    TOMSHLEY_CICD_MIRROR_URL: "git@bitbucket.org:org/repo.git"
    TOMSHLEY_CICD_MIRROR_BRANCH_MAP: "main:main,develop:develop"
```

**Bitbucket `bitbucket-pipelines.yml`** (reverse mirror — develop-* only):
```yaml
pipelines:
  branches:
    'develop-*':
      - step:
          name: "Mirror to GitLab"
          script:
            - *toolbox-ensure-tools
            - *toolbox-debug
            - *toolbox-core-env
            - export TOMSHLEY_CICD_MIRROR_URL="git@gitlab.com:org/repo.git"
            - export TOMSHLEY_CICD_MIRROR_BRANCH_MAP="develop-*:develop-*"
            - export TOMSHLEY_CICD_MIRROR_FORCE_PUSH="false"
            - *toolbox-bootstrap
            - bash "${TOMSHLEY_CICD_TOOLBOX_ROOT}/mirror/sync.sh"
```

**Loop safety:** GitLab pushes only `main`/`develop`; Bitbucket pushes only `develop-*`. Disjoint.

### Recipe C: Cron-Driven Reverse Sync (no secondary platform CI required)

Useful when the secondary platform's CI is unavailable or you want a scheduled backstop for pull-based mirroring.

**GitLab Schedule** (Settings > CI/CD > Schedules, every 15 min):
```yaml
# In .gitlab-ci.yml
tomshley-cicd-mirror-poll:
  variables:
    TOMSHLEY_CICD_MIRROR_POLL_URL: "git@bitbucket.org:org/repo.git"
    TOMSHLEY_CICD_MIRROR_POLL_BRANCH_PATTERNS: "develop-*"
    TOMSHLEY_CICD_MIRROR_POLL_SSH_KEY: ".secure_files/bitbucket_deploy_key"
```

---

## Adapter-Mapped Variables (set by adapter YAML, consumed by `platform/toolbox-entry.sh`)

These map platform-native CI variables to the toolbox interface.
Set them in the adapter YAML (GitLab `variables:` block, Bitbucket `script` exports).
`platform/toolbox-entry.sh` validates that all required variables are present.

| Variable | Required? | Default | Description |
|----------|-----------|---------|-------------|
| `TOMSHLEY_CICD_TOOLBOX_ROOT` | No | `/opt/tomshley-cicd-pipelines-toolbox` | Root path to the toolbox scripts. Override this to use a checkout-local toolbox tree, for example `${CI_PROJECT_DIR}/toolbox/scripts/tomshley-cicd-pipelines-toolbox` in self-hosting pipelines. |

| Variable | Required? | GitLab source | Bitbucket source |
|----------|-----------|--------------|------------------|
| `TOMSHLEY_CICD_PROJECT_DIR` | Yes | `${CI_PROJECT_DIR}` | `${BITBUCKET_CLONE_DIR}` |
| `TOMSHLEY_CICD_GIT_USER_EMAIL` | Yes | `${GITLAB_USER_EMAIL}` | `pipeline@noreply.bitbucket.org` |
| `TOMSHLEY_CICD_GIT_USER_NAME` | Yes | `${GITLAB_USER_NAME}` | `"Bitbucket Pipeline"` |
| `TOMSHLEY_CICD_CURRENT_BRANCH` | No | `${CI_COMMIT_BRANCH}` | `${BITBUCKET_BRANCH}` |
| `TOMSHLEY_CICD_TAG` | No | `${CI_COMMIT_TAG}` | `${BITBUCKET_TAG}` |

### Adapter-Mapped Publish Variables (consumed by `platform/publish-policy.sh` and `publish/*.sh`)

GitLab defaults every endpoint to the current project's package registry and the
credential to the job token. Bitbucket has no package registry, so consumers set
the endpoints and credential as repository variables or in `.secure_files/.env`.

| Variable | Required? | GitLab source | Bitbucket source |
|----------|-----------|--------------|------------------|
| `TOMSHLEY_CICD_REF_SLUG` | Branch pipelines | `${CI_COMMIT_REF_SLUG}` | `${BITBUCKET_BRANCH}` normalized the same way (lowercase, non-alphanumerics to `-`, ≤ 63 chars) |
| `TOMSHLEY_CICD_COMMIT_SHA` | Branch pipelines | `${CI_COMMIT_SHORT_SHA}` | first 8 chars of `${BITBUCKET_COMMIT}` |
| `TOMSHLEY_CICD_PACKAGE_TOKEN` | Package publish | `${CI_JOB_TOKEN}` unless overridden | repository variable / `.secure_files/.env` |
| `TOMSHLEY_CICD_PACKAGE_USER` | Python publish | `gitlab-ci-token` unless overridden | repository variable |
| `TOMSHLEY_CICD_PUBLISH_AUTH_HEADER` | API uploads, retention | `JOB-TOKEN: <token>` unless overridden | repository variable (complete header) |
| `TOMSHLEY_CICD_PACKAGES_API_URL` | Python rolling cleanup, retention | `<api>/projects/<id>/packages` | repository variable — collection URL supporting list and `DELETE <url>/<id>` |
| `TOMSHLEY_CICD_GENERIC_UPLOAD_URL_TEMPLATE` | generic, Cargo, release assets | `<api>/projects/<id>/packages/generic/%s/%s/%s` | repository variable — `printf` template receiving package, version, filename |
| `TOMSHLEY_CICD_RELEASE_API_URL` | release assets | `<api>/projects/<id>/releases` | repository variable (unset = upload only, no release) |
| `TOMSHLEY_CICD_NPM_REGISTRY` | npm publish | `<api>/projects/<id>/packages/npm/` | repository variable |
| `TOMSHLEY_CICD_NPM_AUTH_KEY` | npm publish | `//<host>/api/v4/projects/<id>/packages/npm/` | repository variable — `.npmrc` key that receives `:_authToken` |
| `TOMSHLEY_CICD_PYPI_REPOSITORY_URL` | Python publish | `<api>/projects/<id>/packages/pypi` | repository variable |

Deleting packages (Python rolling cleanup, retention) needs more than a job token
grants on most registries; override `TOMSHLEY_CICD_PACKAGE_TOKEN` (and therefore
the auth header) with a token that has package-maintainer permissions for those jobs.

### Derived by `toolbox-entry.sh` (do NOT set manually)

| Variable | Logic |
|----------|-------|
| `TOMSHLEY_CICD_IS_TAG` | `"true"` if `TOMSHLEY_CICD_TAG` is non-empty, `"false"` otherwise |

---

## Adapter-Level Variables (set in platform YAML, NOT in toolbox)

These are set by the CI platform's YAML configuration (workflow rules, variable blocks)
and are NOT handled by the toolbox scripts.

| Variable | Purpose |
|----------|---------|
| `CICD_PIPELINES_FLOW_IMAGE` | Image used by GitLab flow, mirror, and most publish-recipe jobs. Defaults to the published `cicd-runner-sbtdockertofu` image for consumers, but can be overridden to a compatible Alpine-based image with `git`, `bash`, and `curl` preinstalled or installable via `apk`. |
| `CICD_PIPELINES_RUST_IMAGE` | Image for `.tomshley-cicd-cargo-zigbuild` — defaults to `cicd-runner-sbtrustdockertofu` (rustup, cargo-zigbuild, zig baked in). Toolchain versions change by bumping the runner, never by installing in a job. |
| `CICD_PIPELINES_PYTHON_IMAGE` | Image for `.tomshley-cicd-publish-python` — defaults to `cicd-runner-pythondocker` (python3 + pip). |
| `TOMSHLEY_CICD_FLOW_TYPE` | Flow type derived from branch pattern matching (e.g. `feature`, `release`, `hotfix`, `develop`, `main`, `tag`) |
| `TOMSHLEY_CICD_BUILD_REVISION` | SHA-based revision suffix for build versioning |
| `TOMSHLEY_CICD_BUILD_VERSION` | Full build version (read from `VERSION` file by adapter bootstrap) |

## Docker Helpers

### switch-to-push-auth.sh

**Path:** `${TOMSHLEY_CICD_TOOLBOX_ROOT}/docker/switch-to-push-auth.sh`

**Purpose:** Switch Docker authentication context from `DOCKER_AUTH_CONFIG` (read) to `~/.docker/config.json` (write) between build and push steps.

**When to use:** Source this script between `docker buildx build` and `docker push` when your pipeline:
- Pulls base images from a different registry/organization than the target registry
- Uses a group-level deploy token that grants cross-org read but not write
- Needs to push to the current project registry using the platform job token

**Usage pattern:**
```bash
docker buildx build -t $CI_REGISTRY_IMAGE:$TAG .
. "${TOMSHLEY_CICD_TOOLBOX_ROOT}/docker/switch-to-push-auth.sh"
docker push $CI_REGISTRY_IMAGE:$TAG
```

**Behavior:**
- **Idempotent** — safe to call multiple times; no-op if `DOCKER_AUTH_CONFIG` is already unset.
- **Diagnostics** — writes `INFO:` to stdout describing the action taken; writes `WARN:` to stderr if `~/.docker/config.json` is missing or empty (indicates a missing `docker login` step in `before_script`).
- **Must be sourced** (`. ` or `source`) — executing as a subshell will not propagate `unset` to the caller.

**Why not in `before_script`:** Unsetting `DOCKER_AUTH_CONFIG` in `before_script` would break `docker buildx build` when pulling cross-org base images. The helper allows fine-grained control between build and push.
