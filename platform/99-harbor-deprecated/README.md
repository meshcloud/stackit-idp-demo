# Harbor Module - DEPRECATED

**⚠️ This module is deprecated and should NOT be used.**

## Why Deprecated?

STACKIT Harbor uses OIDC authentication (`auth_mode: oidc_auth`) and does not provide admin username/password credentials that would be required by the Harbor Terraform provider.

## Current Architecture

Per [ADR-001](../../docs/adr/ADR-001_harbor-registry-strategy.md):

- **Harbor Project**: `registry` (pre-existing, manually created)
- **Robot Account**: `robot$registry+robotaccount` (pre-existing, manually created)
- **Authentication**: Use existing robot account credentials from environment variables

## How Harbor is Used

Harbor credentials are consumed by:

1. **ArgoCD** (`03-argocd`) - Creates pull secret in `argocd` namespace
2. **Building Blocks** (`building-blocks/namespace-with-argocd`) - Creates pull secret in each app namespace
3. **GitHub Actions** - Uses robot credentials to push images (configured as repository secrets)

All modules receive Harbor robot credentials via environment variables:
- `HARBOR_ROBOT_USERNAME=robot$registry+robotaccount`
- `HARBOR_ROBOT_TOKEN=<token>`

## Migration Notes

This module was previously `02-harbor` but has been renamed to `99-harbor-deprecated` to maintain proper deployment order:

**New Order**:
1. `00-state-bucket` - S3 backend for Terraform state
2. `01-ske` - STACKIT Kubernetes Engine cluster
3. `02-meshstack` - meshStack integration
4. `03-argocd` - ArgoCD with Harbor pull secret

**Old Order** (deprecated):
1. ~~`02-harbor`~~ ← Skipped
