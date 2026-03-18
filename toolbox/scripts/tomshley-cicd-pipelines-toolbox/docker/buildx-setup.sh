#!/usr/bin/env sh
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Docker Buildx Setup
#
# Configures the default Buildx builder for use inside rootless DinD
# environments. The docker-container driver (which creates a nested
# BuildKit container) requires sysfs mount — rootless DinD cannot
# provide this. Using the default builder avoids the nested container
# entirely and works on any CI platform (GitLab, Bitbucket, GitHub, etc.).
#
# This script is idempotent and safe to call multiple times.
#
# Usage:
#   /opt/tomshley-cicd-pipelines-toolbox/docker/buildx-setup.sh
#
# ---------------------------------------------------------------------------

set -eu

docker buildx use default
docker buildx inspect default --bootstrap
