# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Root dispatcher Makefile for cicd-pipelines.
#
# Usage:
#   make test            Run conformance tests
#   make gitlab-build    Build GitLab runner images (--load)
#   make gitlab-push     Push GitLab runner images to registry

.PHONY: test gitlab-build gitlab-build-load gitlab-push gitlab-check help

help:
	@echo "Available targets:"
	@echo "  test              Run conformance tests"
	@echo "  gitlab-build      Build GitLab runner images"
	@echo "  gitlab-build-load Build GitLab runner images (--load to local Docker)"
	@echo "  gitlab-push       Push GitLab runner images to registry"
	@echo "  gitlab-check      Print bake file (dry-run)"

test:
	@echo "=== Running conformance tests ==="
	bash common/tests/conformance.sh
	bash common/tests/validate-gitlab.sh
	bash common/tests/validate-bitbucket.sh

gitlab-build:
	$(MAKE) -C gitlab build

gitlab-build-load:
	$(MAKE) -C gitlab build-load

gitlab-push:
	$(MAKE) -C gitlab push

gitlab-check:
	$(MAKE) -C gitlab check
