# Known Issues

## Self-hosting bootstrap during `v0.5.0` cutover

When this repository self-hosts gitflow jobs on a release branch, the adapter default
`CICD_PIPELINES_RUNNER_TAG` may point at a pinned release image that is not published yet.
If that happens, jobs can fail with `manifest unknown`.

Workaround:
- In this repository's `.gitlab-ci.yml`, temporarily override `CICD_PIPELINES_RUNNER_TAG`
  to a published `develop-*` image tag until the `0.5.0` runner images are published.
