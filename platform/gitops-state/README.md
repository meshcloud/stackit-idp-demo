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

### `app-env.yaml` - Environment Configuration (Helm Values)

**Format:** Helm chart values file (YAML, no apiVersion/kind/metadata)  
**Who writes it?** Platform operator or meshStack Building Block automation  
**Who reads it?** ArgoCD (merges with release.yaml as Helm values)  
**What does it control?**
- Deployment shape: replicas, resources, port
- Ingress exposure: hostname, path, TLS
- Environment variables (from config.env list)

**Lifecycle:** Created once per environment, updated when app team wants to change runtime config

**NOT written by:** Release Controller or app-env-config Building Block

### `release.yaml` - Release State (Helm Values)

**Format:** Helm chart values file (YAML, no apiVersion/kind/metadata)  
**Who writes it?** Platform operator (manually) OR app-env-config Building Block (automated)  
**Who reads it?** ArgoCD (merges with app-env.yaml as Helm values)  
**What does it control?**
- Container image reference: repository, tag, digest
- Metadata: when observed, by whom, promotion history

**Lifecycle:** Updated whenever a new image is released to the registry

**NOT written by:** Application teams (only registry push)

> app-env.yaml and release.yaml are plain Helm values files.
> They are merged by ArgoCD and rendered by the platform Helm chart.
> They are not Kubernetes resources.

## ArgoCD Reconciliation Flow

1. **ArgoCD Application CR** watches this Git repository (main branch)
2. **ArgoCD** discovers `app-env.yaml` and `release.yaml` files in the paths specified by Application CR
3. For each environment:
   - Read `app-env.yaml` (deployment config: replicas, port, resources, ingress, env vars)
   - Read `release.yaml` (image reference: repository, tag, digest)
   - **Merge** both files as Helm chart values
   - **Render** platform-owned Helm chart (`app-deployment`) using merged values
   - **Deploy** resulting Kubernetes objects (Deployment, Service, Ingress) into target namespace

4. **Application teams** build and push container images to Harbor registry
5. **app-env-config Building Block** is triggered by developer (or future automation)
   - Updates `release.yaml` with new image reference
   - Commits to Git
6. **Git change** is detected by ArgoCD
7. **ArgoCD redeploys** with new image automatically (continuous reconciliation)

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
