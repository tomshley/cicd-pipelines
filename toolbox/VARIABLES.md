# Toolbox Environment Variables

Reference for consumers of the cicd-pipelines toolbox.

Variables are organized by who sets them and where they are used.

---

## Consumer Variables (you set these)

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
| `TOMSHLEY_CICD_MIRROR_BRANCH_MAP` | No | `""` | Comma-separated `src:dst` pairs (overrides BRANCHES when set) |
| `TOMSHLEY_CICD_MIRROR_TAGS` | No | `"true"` | Mirror tags: `true` or `false` |
| `TOMSHLEY_CICD_MIRROR_SSH_KEY` | No | `""` | Path to SSH key file (e.g. in `.secure_files/`) |
| `TOMSHLEY_CICD_MIRROR_FORCE_PUSH` | No | `"true"` | `true` = `--force`, `false` = `--force-with-lease` |

---

## Adapter-Mapped Variables (set by adapter YAML, consumed by `platform/toolbox-entry.sh`)

These map platform-native CI variables to the toolbox interface.
Set them in the adapter YAML (GitLab `variables:` block, Bitbucket `script` exports).
`platform/toolbox-entry.sh` validates that all required variables are present.

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
| `TOMSHLEY_CICD_FLOW_TYPE` | Flow type derived from branch pattern matching (e.g. `feature`, `release`, `hotfix`, `develop`, `main`, `tag`) |
| `TOMSHLEY_CICD_BUILD_REVISION` | SHA-based revision suffix for build versioning |
| `TOMSHLEY_CICD_BUILD_VERSION` | Full build version (read from `VERSION` file by adapter bootstrap) |
