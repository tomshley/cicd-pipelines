#
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024–2026 Tomshley LLC
#
# Shared Docker Buildx bake targets.
# Include from a platform Makefile (gitlab/, bitbucket/) after setting:
#   BAKE_FILE    — path to docker-bake.hcl
#   BUILDX_NAME  — unique buildx builder instance name

.DEFAULT_GOAL := all

#region Shared defaults
# ------------------------------------------------------------------------------
# Shared defaults (root Makefile exports override these)
# ------------------------------------------------------------------------------

REGISTRY ?= registry.gitlab.com/tomshley/brands/global/tware/tech/products/provisioning/cicd-pipelines
BASE_CONTAINERS_REGISTRY ?= registry.gitlab.com/tomshley/brands/global/tware/tech/products/provisioning/base-containers
BASE_CONTAINERS_UPSTREAM_TAG ?= latest
TAG ?= local
TAG_LATEST ?= local-latest
LOCAL_PLATFORM ?= linux/amd64
#endregion Shared defaults

#region BuildX
# ------------------------------------------------------------------------------
# BuildX
# ------------------------------------------------------------------------------

.PHONY: createbuildx

createbuildx:
	@docker buildx use default
	@docker buildx inspect default --bootstrap
#endregion BuildX

#region Build targets
# ------------------------------------------------------------------------------
# Build targets
# ------------------------------------------------------------------------------

.PHONY: all build build-load push check

all: build

build: createbuildx
	TAG=$(TAG) TAG_LATEST=$(TAG_LATEST) \
	REGISTRY=$(REGISTRY) \
	BASE_CONTAINERS_REGISTRY=$(BASE_CONTAINERS_REGISTRY) \
	BASE_CONTAINERS_UPSTREAM_TAG=$(BASE_CONTAINERS_UPSTREAM_TAG) \
	docker buildx bake -f $(BAKE_FILE)

build-load: createbuildx
	TAG=$(TAG) TAG_LATEST=$(TAG_LATEST) \
	REGISTRY=$(REGISTRY) \
	BASE_CONTAINERS_REGISTRY=$(BASE_CONTAINERS_REGISTRY) \
	BASE_CONTAINERS_UPSTREAM_TAG=$(BASE_CONTAINERS_UPSTREAM_TAG) \
	docker buildx bake -f $(BAKE_FILE) --set '*.platform=$(LOCAL_PLATFORM)' --load

push: createbuildx
	TAG=$(TAG) TAG_LATEST=$(TAG_LATEST) \
	REGISTRY=$(REGISTRY) \
	BASE_CONTAINERS_REGISTRY=$(BASE_CONTAINERS_REGISTRY) \
	BASE_CONTAINERS_UPSTREAM_TAG=$(BASE_CONTAINERS_UPSTREAM_TAG) \
	docker buildx bake -f $(BAKE_FILE) --push

check:
	@echo "Checking bake file..."
	TAG=$(TAG) TAG_LATEST=$(TAG_LATEST) \
	REGISTRY=$(REGISTRY) \
	BASE_CONTAINERS_REGISTRY=$(BASE_CONTAINERS_REGISTRY) \
	BASE_CONTAINERS_UPSTREAM_TAG=$(BASE_CONTAINERS_UPSTREAM_TAG) \
	docker buildx bake -f $(BAKE_FILE) --print
#endregion Build targets
