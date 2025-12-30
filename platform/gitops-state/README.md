# GitOps State Directory Layout

## Stable Identifiers Principle

All directory paths use **stable technical identifiers** (IDs or immutable slugs), NOT mutable display names.

**Why?** In meshStack, workspace/project/tenant names may be renamed or reorganized. GitOps paths must remain stable to avoid accidental redeployments, drift, or loss of history.

## Directory Structure

```
workspaces/<workspace-id>/
  projects/<project-id>/
    tenants/<tenant-id>/
      app-env.yaml    # Environment configuration (human-readable, app-team influence)
      release.yaml    # Deployment release state (machine-written by Release Controller)
```

## Example

```
workspaces/likvid/
  projects/hello-api/
    tenants/dev/
      app-env.yaml
      release.yaml
```

### Path Components

| Component | Example | Type | Owner | Mutable |
|-----------|---------|------|-------|---------|
| `workspace-id` | `likvid` | meshStack workspace ID | Platform | No (stable ID) |
| `project-id` | `hello-api` | meshStack project ID | Platform | No (stable ID) |
| `tenant-id` | `dev` | meshStack tenant/environment name | Platform | No (immutable slug) |

## File Responsibilities

### `app-env.yaml` - Platform Contract (read by ArgoCD + Release Controller)

**Who writes it?** Platform operator or meshStack Building Block automation  
**Who reads it?** ArgoCD (via Helm values) + Release Controller (to find environments)  
**What does it control?**
- Target namespace (must start with `app-`)
- Registry repository mapping (Release Controller uses this)
- Runtime parameters: replicas, resources, port, ingress
- Environment variables and building block references

**Lifecycle:** Created once per environment, updated when app team wants to change runtime config

**NOT written by:** Release Controller (Release Controller only updates release.yaml)

### `release.yaml` - Deployment Release State (machine-written)

**Who writes it?** Platform operator OR Release Controller (future automation)  
**Who reads it?** ArgoCD deployment template (Helm chart)  
**What does it control?**
- Container image reference (repository + tag + digest)
- Metadata: when observed, by whom, promotion history

**Lifecycle:** Updated whenever a new image is released to the registry

**NOT written by:** Application teams (only registry push)

## ArgoCD Reconciliation Flow

1. **ArgoCD Application CR** watches this Git repository
2. **ArgoCD** discovers all `app-env.yaml` files recursively
3. For each `app-env.yaml`:
   - Extract `spec.target.namespace` (e.g., `app-likvid-hello-api-dev`)
   - Read paired `release.yaml` in same directory
   - **Merge** app-env.yaml + release.yaml into deployment template values
   - **Render** platform-owned Helm chart using merged values
   - **Deploy** resulting Kubernetes objects into target namespace

4. **Application teams** push container images to registry
5. **Release Controller** (future) detects image → updates `release.yaml`
6. **Git change** triggers ArgoCD → automatic deployment

## Stable ID Examples

### ✅ Correct (stable, immutable)
```
workspaces/likvid/projects/hello-api/tenants/dev/app-env.yaml
workspaces/acme-corp/projects/payment-api/tenants/staging/app-env.yaml
```

### ❌ Wrong (mutable, breaks on rename)
```
workspaces/John's Workspace/projects/Hello API/tenants/Development/app-env.yaml
# ↑ breaks if workspace is renamed
```

## Implications for meshStack Integration

- meshStack workspace/project/tenant IDs are **stable** across renames
- Platform automation must translate meshStack resource creation → stable ID paths
- Building Blocks must use workspace/project/tenant IDs (not display names)
- Release Controller must search for matching `app-env.yaml` by `registry.repository`

## Future Enhancements

- Multi-workspace deployments (currently single workspace)
- Production promotion workflow (staging → prod via `release.yaml` updates)
- Environment variable inheritance (workspace/project defaults)
- Cross-tenant deployments (multi-tenancy patterns)
