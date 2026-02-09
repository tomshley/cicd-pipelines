#
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024–2026 Tomshley LLC
#
# Root dispatcher Makefile for cicd-pipelines.
# Loads shared configuration and delegates to platform sub-Makefiles.

.DEFAULT_GOAL := help

#region Pinned versions
# ------------------------------------------------------------------------------
# Pinned upstream dependency versions (baseline defaults)
# ------------------------------------------------------------------------------

ifneq ("$(wildcard PINNED_PIPELINE_VERSIONS)","")
  $(info Loading PINNED_PIPELINE_VERSIONS)
  include PINNED_PIPELINE_VERSIONS
  export
endif
#endregion Pinned versions

#region Secure environment overrides
# ------------------------------------------------------------------------------
# Optional secure environment overrides (loaded second so local values win)
# ------------------------------------------------------------------------------

ifneq ("$(wildcard .secure-files/.env)","")
  $(info Loading .secure-files/.env)
  include .secure-files/.env
  export
endif
#endregion Secure environment overrides

#region Docker / BuildKit defaults
# ------------------------------------------------------------------------------
# Docker / BuildKit defaults
# ------------------------------------------------------------------------------

export DOCKER_BUILDKIT ?= 1
export DOCKER_CLI_EXPERIMENTAL ?= enabled
export BUILDKIT_PROGRESS ?= plain
#endregion Docker / BuildKit defaults

#region Versioning
# ------------------------------------------------------------------------------
# VERSION-derived defaults (CI can override)
# ------------------------------------------------------------------------------

VERSION_FILE ?= VERSION
VERSION := $(shell cat $(VERSION_FILE) 2>/dev/null || echo dev)
#endregion Versioning

#region Registry coordinates
# ------------------------------------------------------------------------------
# Shared registry coordinates (consumed by platform sub-Makefiles)
# Fallbacks only apply when PINNED_PIPELINE_VERSIONS is absent.
# ------------------------------------------------------------------------------

export BASE_CONTAINERS_REGISTRY    ?= registry.gitlab.com/tomshley/brands/global/tware/tech/products/provisioning/base-containers
export BASE_CONTAINERS_UPSTREAM_TAG ?= latest
export CICD_PIPELINES_RUNNER_TAG   ?= $(BASE_CONTAINERS_UPSTREAM_TAG)
#endregion Registry coordinates

#region Local platform detection
# ------------------------------------------------------------------------------
# Local single-arch helper (needed for --load)
# ------------------------------------------------------------------------------

UNAME_M := $(shell uname -m)

ifeq ($(UNAME_M),x86_64)
  LOCAL_PLATFORM ?= linux/amd64
else ifeq ($(UNAME_M),aarch64)
  LOCAL_PLATFORM ?= linux/arm64
else ifeq ($(UNAME_M),arm64)
  LOCAL_PLATFORM ?= linux/arm64
else ifneq (,$(findstring armv7,$(UNAME_M)))
  LOCAL_PLATFORM ?= linux/arm/v7
else ifneq (,$(findstring armv6,$(UNAME_M)))
  LOCAL_PLATFORM ?= linux/arm/v6
else
  LOCAL_PLATFORM ?= linux/amd64
endif

export LOCAL_PLATFORM
#endregion Local platform detection

#region Help
# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------

.PHONY: help
help:
	@echo "Tomshley CI/CD Pipelines"
	@echo
	@echo "Targets:"
	@echo "  make test              Run conformance tests"
	@echo "  make gitlab-build      Build GitLab runner images"
	@echo "  make gitlab-build-load Build+load GitLab runner images for LOCAL_PLATFORM=$(LOCAL_PLATFORM)"
	@echo "  make gitlab-push       Push GitLab runner images to registry"
	@echo "  make gitlab-check      Print bake file (dry-run)"
	@echo
	@echo "Resolved variables:"
	@echo "  BASE_CONTAINERS_REGISTRY=$(BASE_CONTAINERS_REGISTRY)"
	@echo "  BASE_CONTAINERS_UPSTREAM_TAG=$(BASE_CONTAINERS_UPSTREAM_TAG)"
	@echo "  CICD_PIPELINES_RUNNER_TAG=$(CICD_PIPELINES_RUNNER_TAG)"
	@echo "  LOCAL_PLATFORM=$(LOCAL_PLATFORM)"
	@echo "  VERSION=$(VERSION)"
#endregion Help

#region Checks
# ------------------------------------------------------------------------------
# Checks
# ------------------------------------------------------------------------------

.PHONY: check
check:
	@command -v docker >/dev/null || { echo "docker not found"; exit 1; }
	@docker buildx version >/dev/null || { echo "docker buildx not available"; exit 1; }
#endregion Checks

#region Test targets
# ------------------------------------------------------------------------------
# Test targets
# ------------------------------------------------------------------------------

.PHONY: test
test:
	@echo "=== Running conformance tests ==="
	bash common/tests/conformance.sh
	bash common/tests/validate-gitlab.sh
	bash common/tests/validate-bitbucket.sh
#endregion Test targets

#region Platform dispatch – GitLab
# ------------------------------------------------------------------------------
# GitLab runner image targets (delegates to gitlab/Makefile)
# ------------------------------------------------------------------------------

.PHONY: gitlab-build gitlab-build-load gitlab-push gitlab-check

gitlab-build:
	$(MAKE) -C gitlab build

gitlab-build-load:
	$(MAKE) -C gitlab build-load

gitlab-push:
	$(MAKE) -C gitlab push

gitlab-check:
	$(MAKE) -C gitlab check
#endregion Platform dispatch – GitLab
