# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Canonical reference implementation for CI/CD version composition in Makefiles.
# This includable fragment provides version and tag variables for Docker builds.
#
# Contract:
# - Read VERSION file from VERSION_FILE variable (defaults to VERSION)
# - Read TOMSHLEY_CICD_BUILD_REVISION from environment
# - Compose VERSION, TAG, and TAG_LATEST variables
# - Provide version-info target for debugging
#
# Usage:
#   include path/to/cicd-pipelines/common/adapter-specs/make/version-tags.mk
#
# @see https://gitlab.com/tomshley/tomshley-oss-dependencies/-/tree/main/cicd-pipelines/common/adapter-specs/

# Configuration
VERSION_FILE ?= VERSION

# Internal helper to read VERSION file
define read_version_file
$(shell if [ -f $(VERSION_FILE) ]; then cat $(VERSION_FILE); else echo "dev"; fi)
endef

# Read base version
VERSION := $(call read_version_file)

# Read revision from environment
REVISION := $(TOMSHLEY_CICD_BUILD_REVISION)

# Compose version tags
ifneq ($(REVISION),)
    TAG := $(VERSION)-$(REVISION)
    TAG_LATEST := $(VERSION)-latest
else
    TAG := $(VERSION)
    TAG_LATEST := $(VERSION)
endif

# Export variables for sub-makes
export VERSION
export TAG
export TAG_LATEST
export REVISION

# Default target
.PHONY: version-info
version-info:
	@echo "Version Information:"
	@echo "  VERSION_FILE: $(VERSION_FILE)"
	@echo "  VERSION: $(VERSION)"
	@echo "  REVISION: $(REVISION)"
	@echo "  TAG: $(TAG)"
	@echo "  TAG_LATEST: $(TAG_LATEST)"

# Help target
.PHONY: help-version-tags
help-version-tags:
	@echo "Version Tags Variables:"
	@echo "  VERSION      - Base version from VERSION file"
	@echo "  TAG          - Composed version tag (VERSION-REVISION or VERSION)"
	@echo "  TAG_LATEST   - Rolling tag (VERSION-latest or VERSION)"
	@echo "  REVISION     - Build revision from TOMSHLEY_CICD_BUILD_REVISION"
	@echo ""
	@echo "Configuration:"
	@echo "  VERSION_FILE - Path to VERSION file (default: VERSION)"
	@echo ""
	@echo "Targets:"
	@echo "  version-info - Display current version information"
	@echo "  help-version-tags - Display this help"
