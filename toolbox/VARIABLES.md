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
| `TOMSHLEY_CICD_FLOW_MESSAGE_PREFIX` | No | `"Tomshley CI Pipeline"` | Prefix for merge/tag commit messages |
| `TOMSHLEY_CICD_FLOW_SKIP_CI_MARKER` | No | `"[skip ci]"` | Marker appended to develop merge messages |
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
| `CICD_PIPELINES_FLOW_IMAGE` | Image used by GitLab flow and mirror jobs. Defaults to the published runner image for consumers, but can be overridden to a compatible Alpine-based image with `git`, `bash`, and `curl` preinstalled or installable via `apk`. |
| `TOMSHLEY_CICD_FLOW_TYPE` | Flow type derived from branch pattern matching (e.g. `feature`, `release`, `hotfix`, `develop`, `main`, `tag`) |
| `TOMSHLEY_CICD_BUILD_REVISION` | SHA-based revision suffix for build versioning |
| `TOMSHLEY_CICD_BUILD_VERSION` | Full build version (read from `VERSION` file by adapter bootstrap) |
