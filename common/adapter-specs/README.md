# Version Adapter Specifications

This directory contains canonical reference implementations for version composition across different build ecosystems. These are **adapter specs** — they define the contract and provide reference code, but are **not published as packages**.

## Contract

Every adapter implements the same contract:

1. **Read VERSION file** — walk up directory tree from current working directory to find `VERSION`
2. **Read TOMSHLEY_CICD_BUILD_REVISION** — environment variable, empty string if not set
3. **Compose version** — ecosystem-specific format:
   - If revision is empty: use base version as-is
   - If revision is non-empty: append revision with ecosystem-appropriate separator

## Environment Variables

| Variable | Source | Purpose |
|----------|--------|---------|
| `TOMSHLEY_CICD_BUILD_VERSION` | `VERSION` file content | Base semantic version (e.g., "1.2.3") |
| `TOMSHLEY_CICD_BUILD_REVISION` | CI environment | Build identifier (e.g., "develop-abc1234") |

## Adapter Details

### SBT (`sbt/CIBuildVersionKeys.scala`)

- **Target**: sbt `version` setting
- **Format**: `base-revision` (hyphen separator)
- **Reference**: Used by magicroot-sbt's `TomshleyCIBuildVersionPlugin`

### Node (`node/sync-version.js`)

- **Target**: `package.json` version field
- **Format**: `base-revision` (hyphen separator)
- **Suffix normalization**: `-SNAPSHOT` → `-0`
- **Usage**: CLI script that reads VERSION + env var, writes package.json

### Python (`python/version_resolver.py`)

- **Target**: setuptools version
- **Format**: `base+revision` (PEP 440 local version identifier)
- **Suffix normalization**: `-SNAPSHOT` → `.dev0`, `-rc.N` → `rcN`
- **Usage**: Importable module or CLI script

### Makefile (`make/version-tags.mk`)

- **Target**: Docker image tags
- **Format**: `base-revision` (hyphen separator)
- **Variables**: `TAG` (pinnable), `TAG_LATEST` (rolling)
- **Usage**: Include fragment for consumer Docker projects

## Testing

Adapter tests validate:
- **Structural conformance**: All adapter files exist and reference `TOMSHLEY_CICD_BUILD_REVISION`
- **Contract compliance**: Runtime tests verify version composition matches expected matrix
- **Suffix normalization**: Cross-ecosystem consistency for edge cases

See `../tests/validate-adapters.sh` for test implementation.

## Usage

Consumers should:
1. Keep their own implementation in their project
2. Add `@see` comment pointing to the canonical adapter spec
3. Ensure their implementation follows the same contract
4. Run adapter tests to verify conformance
