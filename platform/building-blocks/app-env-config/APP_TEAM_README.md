# Update Release for Your Application

## What Does This Do?

The **app-env-config** Building Block updates the desired container image version for your application in the platform's GitOps state repository. Think of it as the **controlled self-service interface for releasing new versions**—you push your container image to Harbor, then use this Building Block to tell the platform which image version to deploy.

## When to Use It?

You want to deploy a new version of your application to a specific environment (dev, staging, or prod). This Building Block provides the approved way to promote container images into production.

## How It Works (3-Minute Flow)

1. **You build and push** a container image to Harbor:
   ```bash
   docker build -t harbor.example.tld/team-a/my-app/dev:2025.01.10-abc123 .
   docker push harbor.example.tld/team-a/my-app/dev:2025.01.10-abc123
   ```

2. **You run the app-env-config Building Block** in meshStack:
   - Select your application environment (dev, staging, prod)
   - Specify the image reference (tag or digest)
   - Click "Execute"

3. **The platform deploys automatically**:
   - The Building Block commits the new image reference to the Git repository
   - ArgoCD detects the change and re-renders your deployment
   - Your new container image is deployed to Kubernetes within seconds

## Required Information

When you run this Building Block, provide:

| Parameter | Example | Description |
| --- | --- | --- |
| **Image Repository** | `harbor.example.tld/team-a/my-app/dev` | Where your images are stored (provided by platform team) |
| **Image Tag** | `2025.01.10-abc123` | The image version to deploy (e.g., git SHA, semantic version) |
| **Environment** | `dev` (or `staging`, `prod`) | Which environment to deploy to (pre-configured by platform team) |
| *(optional) App Name* | `my-app` | Your application name (for logs and traceability) |

## What Gets Created?

The Building Block creates/updates a single file in the platform's GitOps state repository:

```
workspaces/<workspace-id>/
  projects/<project-id>/
    tenants/<tenant-id>/
      release.yaml  ← This file is created/updated
```

This is a **Helm chart values file** (not a Kubernetes manifest) that ArgoCD will merge with `app-env.yaml` before rendering the deployment.

Example `release.yaml`:

```yaml
deployment:
  image:
    repository: harbor.example.tld/team-a/my-app/dev
    tag: "2025.01.10-abc123"
    digest: null

# Operational metadata for audit trail
_metadata:
  observedAt: "2025-01-10T14:23:45Z"
  observedBy: "app-env-config-building-block"
  app: "my-app"
  environment: "dev"
```

**How it integrates with deployments:**

1. Your `app-env.yaml` defines scaling, resources, ingress config, env variables
2. The `release.yaml` file (created by app-env-config) specifies the image to deploy
3. **ArgoCD merges both files** as Helm values
4. ArgoCD renders the platform Helm chart with merged values
5. Kubernetes workloads are deployed with the specified image

## Shared Responsibilities

| Task | Who | Notes |
| --- | --- | --- |
| **Build container images** | You (App Team) | Use your preferred build tool (local Docker, Gitea CI, etc.) |
| **Push to Harbor** | You (App Team) | Your registry push credentials are configured automatically |
| **Choose which image to deploy** | You (App Team) | Via this Building Block (controlled self-service) |
| **Update GitOps state** | Platform (app-env-config) | Automatic—commits to Git, auditable, reversible |
| **Deploy to Kubernetes** | Platform (ArgoCD) | Automatic—detects Git changes, applies manifests |
| **Monitor & manage cluster** | Platform Team | Kubernetes, networking, security policies |

## What Happens If Something Goes Wrong?

- **Invalid image reference?** The Building Block will fail; check your Harbor path and tag.
- **Want to roll back?** It's just a Git commit. You can `git revert` or manually edit `release.yaml` and commit.
- **Need to modify app configuration?** The `app-env.yaml` file (separate from `release.yaml`) stores your scaling, resources, and ingress settings. Contact your platform team to update it.

## Example Workflow

```bash
# 1. Developer builds and pushes a new image
$ docker build -t harbor.example.tld/team-a/hello-api/dev:v1.2.3 .
$ docker push harbor.example.tld/team-a/hello-api/dev:v1.2.3

# 2. Developer runs app-env-config Building Block in meshStack:
#    - Image Repository: harbor.example.tld/team-a/hello-api/dev
#    - Image Tag: v1.2.3
#    - Environment: dev

# 3. Platform commits release.yaml automatically:
#    Commit message: "Update release for hello-api/dev: 
#                     harbor.example.tld/team-a/hello-api/dev:v1.2.3"

# 4. ArgoCD deploys within seconds
#    (check in meshStack Portal or via kubectl)
```

## Key Differences from Manual Git

You **could** manually edit `release.yaml` and push to Git, but the app-env-config Building Block is preferred because it:

- ✅ Ensures only **approved image repositories** can be used (no side-channel deployments)
- ✅ Provides an **audit trail** in meshStack of who deployed what and when
- ✅ **Validates** image references before writing to Git
- ✅ Prevents **accidental overwrite** of shared GitOps state
- ✅ Works **offline**—no need to clone Git locally

## Support & Questions

Contact your platform team if:
- You don't know your image repository path
- You want to add a new environment (dev → staging → prod)
- You need to modify `app-env.yaml` (scaling, resources, ingress)
- Deployments are not appearing after running this Building Block
