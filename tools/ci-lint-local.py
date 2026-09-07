#!/usr/bin/env python3
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
"""Lint consumer pipelines against the working-tree GitLab adapter.

GitLab's CI lint endpoint resolves `include:` against published refs, so a
consumer pipeline that pins an unreleased adapter cannot be linted as-is. This
maintainer tool drops the consumer's `include:` block, prepends the local
adapter (minus its `variables:` block, since the consumer's block is the
override surface), and submits the merged configuration to the project-scoped
lint endpoint.

    GITLAB_TOKEN=... tools/ci-lint-local.py adapters/gitlab/ci/adapter.yml \\
        --project-id <consumer project id> path/to/consumer/.gitlab-ci.yml

The project id scopes the lint to a real project so project-level CI/CD
settings and permissions apply; any consumer project id the token can read
works.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path


def without_top_level_block(lines: list[str], key: str) -> list[str]:
    """Return `lines` with the top-level YAML mapping `key:` removed."""
    start = next((index for index, line in enumerate(lines) if line.rstrip() == f"{key}:"), None)
    if start is None:
        return lines
    end = next(
        (
            index
            for index in range(start + 1, len(lines))
            if lines[index].strip() and not lines[index][0].isspace() and not lines[index].lstrip().startswith("#")
        ),
        len(lines),
    )
    return lines[:start] + lines[end:]


def inline(adapter: Path, consumer: Path) -> str:
    adapter_lines = without_top_level_block(adapter.read_text().splitlines(keepends=True), "variables")
    consumer_lines = without_top_level_block(consumer.read_text().splitlines(keepends=True), "include")
    return "".join(adapter_lines + ["\n"] + consumer_lines)


def lint(content: str, endpoint: str, token: str | None) -> dict[str, object]:
    request = urllib.request.Request(
        endpoint,
        data=json.dumps({"content": content, "include_merged_yaml": True}).encode(),
        headers={"Content-Type": "application/json", **({"PRIVATE-TOKEN": token} if token else {})},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        return {"status": "error", "errors": [f"HTTP {error.code}: {error.read().decode(errors='replace')}"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("adapter", type=Path, help="local adapters/gitlab/ci/adapter.yml")
    parser.add_argument("consumers", nargs="+", type=Path, help="consumer .gitlab-ci.yml files")
    parser.add_argument("--endpoint", default="https://gitlab.com/api/v4", help="GitLab API v4 base URL")
    parser.add_argument("--project-id", required=True, type=int, help="project id scoping the lint")
    args = parser.parse_args()

    token = os.environ.get("GITLAB_TOKEN")
    endpoint = f"{args.endpoint}/projects/{args.project_id}/ci/lint"
    failures = 0
    for consumer in args.consumers:
        result = lint(inline(args.adapter, consumer), endpoint, token)
        valid = result.get("valid") is True
        print(f"{consumer}: {'valid' if valid else 'invalid'}")
        errors = result.get("errors", [])
        for error in errors if isinstance(errors, list) else [errors]:
            print(f"  {error}")
        failures += not valid
    return int(failures > 0)


if __name__ == "__main__":
    sys.exit(main())
