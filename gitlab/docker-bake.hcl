# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Docker Buildx Bake file for cicd-pipelines GitLab runner images.
# Context paths are relative to gitlab/ (this file lives in gitlab/).
# Run: cd gitlab && docker buildx bake -f docker-bake.hcl

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "TAG" {
  default = "local"
}
variable "TAG_LATEST" {
  default = "local-latest"
}
variable "REGISTRY" {
  default = "registry.gitlab.com/tomshley/brands/global/tware/tech/products/provisioning/cicd-pipelines"
}
variable "BASE_CONTAINERS_REGISTRY" {
  default = "registry.gitlab.com/tomshley/brands/global/tware/tech/products/provisioning/base-containers"
}
variable "BASE_CONTAINERS_UPSTREAM_TAG" {
  default = "latest"
}

# ---------------------------------------------------------------------------
# Groups
# ---------------------------------------------------------------------------

group "default" {
  targets = ["runner-sbtdockertofu"]
}

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

target "runner-sbtdockertofu" {
  context    = "runners/sbtdockertofu"
  dockerfile = "Dockerfile"
  contexts = {
    os_docker_build_ref                          = "docker-image://${BASE_CONTAINERS_REGISTRY}/base-alpine-3_23-upstream:${BASE_CONTAINERS_UPSTREAM_TAG}"
    lang_java_jdk_docker_build_ref               = "docker-image://${BASE_CONTAINERS_REGISTRY}/foundation-runtime-java-21-jdk-openjdk-upstream:${BASE_CONTAINERS_UPSTREAM_TAG}"
    entry_docker_cli_buildx_docker_build_ref     = "docker-image://${BASE_CONTAINERS_REGISTRY}/entry-docker-cli-buildx-29-vendored:${BASE_CONTAINERS_UPSTREAM_TAG}"
    entry_sbt_docker_build_ref                   = "docker-image://${BASE_CONTAINERS_REGISTRY}/entry-sbt-1_12-vendored:${BASE_CONTAINERS_UPSTREAM_TAG}"
    entry_opentofu_docker_build_ref              = "docker-image://${BASE_CONTAINERS_REGISTRY}/entry-opentofu-1_11-vendored:${BASE_CONTAINERS_UPSTREAM_TAG}"
  }
  tags = [
    "${REGISTRY}/cicd-gitlab-runner-sbtdockertofu:${TAG}",
    "${REGISTRY}/cicd-gitlab-runner-sbtdockertofu:${TAG_LATEST}"
  ]
  platforms = ["linux/amd64"]
}
