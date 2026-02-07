<p>
  <img src="assets/brand/logo.svg" alt="Tomshley Logo" width="200"/>
</p>

# Tomshley CI/CD Pipelines

Reusable GitLab CI/CD templates for Tomshley OSS projects.

This repository is part of the **Tomshley – OSS IP Division** and is maintained by **Tomshley LLC**.

---

## Overview

This repository provides shared, reusable CI/CD pipeline templates designed to be consumed by downstream Tomshley projects. Templates are organized by platform and concern:

- **gitlab/** — GitLab CI/CD runner configurations and templates
- **common/** — Cross-platform runner definitions

---

## Design Goals

- Template-driven, composable CI/CD
- Minimal, explicit pipeline logic
- Git Flow aware (feature, release, hotfix, tag)
- Reusable across all Tomshley OSS repositories

---

## Usage

Include templates in your `.gitlab-ci.yml`:

```yaml
include:
  - project: 'tomshley/cicd-pipelines'
    file: '/gitlab/templates/<template-name>.yml'
```

---

## Contributing

See CONTRIBUTING.md.

---

## Security

See SECURITY.md.

---

## License

Apache License 2.0. See LICENSE and NOTICE.md.

---

## Credits

Maintained by Tomshley LLC.
Tomshley and the Tomshley logo are trademarks of Tomshley LLC.
