# Common — Spec-Driven Conformance Model

This directory defines the **behavioral contracts** that every CI platform
implementation must satisfy.

## How It Works

1. **`specs/`** — Machine-readable YAML contracts (source of truth)
2. **Platform dirs** (`gitlab/ci/`, `bitbucket/ci/`) — Implement the specs
3. **`tests/conformance.sh`** — Validates all platforms against specs on every push

## Platform Maturity

| Status | On failure |
|---|---|
| `active` | CI fails |
| `in-development` | CI warns |
| `roadmap` | Skipped |

## Running Locally

    make test
