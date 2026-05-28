#!/usr/bin/env sh
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Docker Push-Auth Switch
#
# Use BETWEEN buildx build and docker push (not in before_script):
#
#   - DOCKER_AUTH_CONFIG (when set from a group-level / cross-org deploy
#     token) typically grants READ on the base-image registry but NOT
#     WRITE on the current project. It must remain set during the image
#     build step so base images pull successfully.
#   - For `docker push`, ~/.docker/config.json (written by the platform's
#     `docker login` step) carries the platform job token which has WRITE
#     on the current project.
#
# Calling this script before `docker push` unsets DOCKER_AUTH_CONFIG so
# the file-based auth takes effect. It is idempotent and a no-op when
# DOCKER_AUTH_CONFIG is already unset.
#
# Usage:
#   docker buildx build ...
#   . "${TOMSHLEY_CICD_TOOLBOX_ROOT}/docker/switch-to-push-auth.sh"
#   docker push ...
#
# IMPORTANT: source (`. ` or `source`) this script — do NOT execute it.
# A subshell `unset` does not propagate to the calling shell.
#
# ---------------------------------------------------------------------------

if [ -n "${DOCKER_AUTH_CONFIG:-}" ]; then
  unset DOCKER_AUTH_CONFIG
  echo "INFO: switch-to-push-auth: DOCKER_AUTH_CONFIG unset; using ~/.docker/config.json for push"
else
  echo "INFO: switch-to-push-auth: DOCKER_AUTH_CONFIG already unset; no-op"
fi

_docker_config_path="${HOME:-/root}/.docker/config.json"
if [ ! -s "${_docker_config_path}" ]; then
  echo "WARN: switch-to-push-auth: ${_docker_config_path} is missing or empty." >&2
  echo "WARN: switch-to-push-auth: ensure the runner's before_script ran 'docker login' before this point." >&2
fi
unset _docker_config_path
