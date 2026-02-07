# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# GitLab runner image build targets.
# Run from: repo-root/gitlab/ (or via root Makefile: make gitlab-build)

REGISTRY ?= registry.gitlab.com/tomshley/brands/global/tware/tech/products/provisioning/cicd-pipelines
BASE_CONTAINERS_REGISTRY ?= registry.gitlab.com/tomshley/brands/global/tware/tech/products/provisioning/base-containers
BASE_CONTAINERS_TAG ?= latest
TAG ?= local
TAG_LATEST ?= local-latest
BAKE_FILE := docker-bake.hcl
BUILDX_NAME := cicd-pipelines_buildx

.PHONY: all build build-load push createbuildx check

all: build

createbuildx:
	@docker buildx inspect $(BUILDX_NAME) >/dev/null 2>&1 || \
		docker buildx create --name $(BUILDX_NAME) --driver docker-container --use
	@docker buildx inspect $(BUILDX_NAME) --bootstrap

build-load: createbuildx
	TAG=$(TAG) TAG_LATEST=$(TAG_LATEST) \
	REGISTRY=$(REGISTRY) \
	BASE_CONTAINERS_REGISTRY=$(BASE_CONTAINERS_REGISTRY) \
	BASE_CONTAINERS_TAG=$(BASE_CONTAINERS_TAG) \
	docker buildx bake -f $(BAKE_FILE) --load

build: createbuildx
	TAG=$(TAG) TAG_LATEST=$(TAG_LATEST) \
	REGISTRY=$(REGISTRY) \
	BASE_CONTAINERS_REGISTRY=$(BASE_CONTAINERS_REGISTRY) \
	BASE_CONTAINERS_TAG=$(BASE_CONTAINERS_TAG) \
	docker buildx bake -f $(BAKE_FILE)

push: createbuildx
	TAG=$(TAG) TAG_LATEST=$(TAG_LATEST) \
	REGISTRY=$(REGISTRY) \
	BASE_CONTAINERS_REGISTRY=$(BASE_CONTAINERS_REGISTRY) \
	BASE_CONTAINERS_TAG=$(BASE_CONTAINERS_TAG) \
	docker buildx bake -f $(BAKE_FILE) --push

check:
	@echo "Checking bake file..."
	docker buildx bake -f $(BAKE_FILE) --print
