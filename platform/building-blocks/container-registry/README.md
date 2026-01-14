# Building Block: Container Registry

## Overview

This building block computes a **deterministic container image repository path** for applications within the Sovereign Developer Platform.

**Status:** v1/Demo Placeholder — No actual registry provisioning, credentials management, or external infrastructure.

## Purpose

- **Platform-owned registry routing:** Centralizes container image naming policy
- **Workspace/Project/Tenant scoping:** Ensures images are organized by organizational structure
- **Integration point:** Output feeds into `app-env-config` and deployment workflows

## Architecture

The module computes a simple image repository path by combining:

```
registry_base / harbor_project / workspace_id / project_id / tenant_id / app_name
```

Example output:
```
registry.onstackit.cloud/platform-demo/my-workspace/hello-api/dev/hello-api
```

## Current Limitations (v1)

- **No Harbor interaction:** Registry and projects must be pre-existing
- **No credential provisioning:** Auth is handled elsewhere (e.g., via `namespace-with-argocd`)
- **Deterministic paths only:** No dynamic per-app registry projects (future option)
- **No sanitization:** Assumes valid input (workspace_id, project_id, app_name)

## Inputs

| Variable | Type | Default | Required | Description |
|----------|------|---------|----------|-------------|
| `workspace_id` | string | — | Yes | meshStack workspace identifier |
| `project_id` | string | — | Yes | meshStack project identifier |
| `tenant_id` | string | — | Yes | Environment identifier (dev/staging/prod) |
| `app_name` | string | — | Yes | Application name |
| `registry_base` | string | `registry.onstackit.cloud` | No | Registry base URL |
| `harbor_project` | string | `platform-demo` | No | Harbor project name |

## Outputs

| Output | Description |
|--------|-------------|
| `registry_base` | Base URL of the container registry |
| `harbor_project` | Harbor project name |
| `image_repository` | Full image repository path (ready for `:tag` or `@digest`) |
| `image_example_tag` | Example image reference with `:release` tag |
| `image_example_digest` | Example image reference with `@sha256:...` digest |

## Usage in Building Blocks

Other building blocks (e.g., `app-env-config`) reference this module:

```hcl
dependency "registry" {
  config_path = "../../building-blocks/container-registry"
}

inputs = {
  image_repository = dependency.registry.outputs.image_repository
}
```

## Future Directions

- **Harbor API integration:** Programmatic project/robot account creation (requires admin credentials or OIDC workflow)
- **Per-app registry projects:** Stronger isolation for production
- **Credential provisioning:** Return pull/push secrets alongside repository path
- **Registry per tenant:** Multi-registry support for regulated environments

## References

- [ADR-001: Harbor Registry Project Strategy](../../docs/adr/ADR-001_harbor-registry-strategy.md)
- [namespace-with-argocd Building Block](../namespace-with-argocd/README.md)
- [app-env-config Building Block](../app-env-config/README.md)
