#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Artifact publish policy — the single implementation of the pinnable/rolling
# tag contract shared by every publish recipe and by the adapters'
# artifact-tag fragments.
#
# This script is SOURCE'd (not executed). It sets no shell options so it
# cannot leak -e/-u/pipefail into the calling job shell.
#
# It consumes ONLY TOMSHLEY_CICD_* variables — the adapter YAML maps the
# platform-native ref slug, short SHA, and tag into this interface.
#
# Required environment variables (set by adapter YAML):
#   TOMSHLEY_CICD_TAG          — tag name (empty on branch pipelines)
#   TOMSHLEY_CICD_REF_SLUG     — normalized branch slug (branch pipelines only)
#   TOMSHLEY_CICD_COMMIT_SHA   — short commit SHA (branch pipelines only)
#
# Exported:
#   CICD_PUBLISH_PINNABLE      — always "true"
#   CICD_PUBLISH_ROLLING       — "true" on branches, "false" on tags
#   CICD_PUBLISH_PINNABLE_TAG  — "{ref-slug}-{sha}" on branches, "" on tags
#                                (a tag pipeline publishes the clean version)
#   CICD_PUBLISH_ROLLING_TAG   — "{ref-slug}-latest" on branches, "latest" on tags
#   CICD_PUBLISH_VERSION       — tag with a leading "v" stripped, "" on branches
#   CICD_PUBLISH_LABELS        — space-separated artifact labels to publish:
#                                the pinnable and rolling tags on branches,
#                                the clean version on tags

if [ -n "${TOMSHLEY_CICD_TAG:-}" ]; then
  export CICD_PUBLISH_PINNABLE="true"
  export CICD_PUBLISH_ROLLING="false"
  export CICD_PUBLISH_PINNABLE_TAG=""
  export CICD_PUBLISH_ROLLING_TAG="latest"
  export CICD_PUBLISH_VERSION="${TOMSHLEY_CICD_TAG#v}"
  export CICD_PUBLISH_LABELS="${CICD_PUBLISH_VERSION}"
else
  : "${TOMSHLEY_CICD_REF_SLUG:?required on branch pipelines — set by adapter YAML}"
  : "${TOMSHLEY_CICD_COMMIT_SHA:?required on branch pipelines — set by adapter YAML}"
  export CICD_PUBLISH_PINNABLE="true"
  export CICD_PUBLISH_ROLLING="true"
  export CICD_PUBLISH_PINNABLE_TAG="${TOMSHLEY_CICD_REF_SLUG}-${TOMSHLEY_CICD_COMMIT_SHA}"
  export CICD_PUBLISH_ROLLING_TAG="${TOMSHLEY_CICD_REF_SLUG}-latest"
  export CICD_PUBLISH_VERSION=""
  export CICD_PUBLISH_LABELS="${CICD_PUBLISH_PINNABLE_TAG} ${CICD_PUBLISH_ROLLING_TAG}"
fi

echo "Artifact publish tags resolved:"
echo "  CICD_PUBLISH_PINNABLE     = ${CICD_PUBLISH_PINNABLE}"
echo "  CICD_PUBLISH_ROLLING      = ${CICD_PUBLISH_ROLLING}"
echo "  CICD_PUBLISH_PINNABLE_TAG = ${CICD_PUBLISH_PINNABLE_TAG:-<empty>}"
echo "  CICD_PUBLISH_ROLLING_TAG  = ${CICD_PUBLISH_ROLLING_TAG}"
echo "  CICD_PUBLISH_VERSION      = ${CICD_PUBLISH_VERSION:-<empty>}"
