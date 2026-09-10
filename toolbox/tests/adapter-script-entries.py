#!/usr/bin/env python3
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
"""Report script entries that a YAML parser reads as mappings, not commands.

A plain (unquoted) sequence entry containing ": " is a mapping in YAML, so
`- echo "Build Version: ${VERSION}"` is not a command and the platform rejects
the configuration. Entries that are quoted, block scalars, or tag directives
(`!reference`) are unambiguous and are left alone.

Prints one finding per line and exits 1 when there are any.
"""

from __future__ import annotations

import sys
from pathlib import Path

SCRIPT_KEYS = ("script", "before_script", "after_script")


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip())


def findings(text: str) -> list[str]:
    reported: list[str] = []
    block_key: str | None = None
    block_indent = 0
    scalar_indent: int | None = None

    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.rstrip("\n")
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = indent_of(line)

        # Inside a block scalar every line is literal content.
        if scalar_indent is not None:
            if indent > scalar_indent:
                continue
            scalar_indent = None

        if block_key is not None and indent <= block_indent and not stripped.startswith("- "):
            block_key = None

        key = stripped.split(":", 1)[0]
        if stripped.endswith(":") and key in SCRIPT_KEYS:
            block_key = key
            block_indent = indent
            continue

        if block_key is None or not stripped.startswith("- "):
            continue

        entry = stripped[2:].strip()
        if not entry or entry[0] in "'\"!|>[" or entry in ("|", ">"):
            if entry in ("|", ">") or entry[:1] in ("|", ">"):
                scalar_indent = indent
            continue

        if ": " in entry or entry.endswith(":"):
            reported.append(f"line {number}: {block_key} entry parses as a mapping: {entry}")

    return reported


def main() -> int:
    status = 0
    for argument in sys.argv[1:]:
        for finding in findings(Path(argument).read_text()):
            print(finding)
            status = 1
    return status


if __name__ == "__main__":
    sys.exit(main())
