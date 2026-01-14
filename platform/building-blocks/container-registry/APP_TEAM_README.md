# Container Registry Building Block — Developer Guide

## Quick Start

This building block provides your **container image repository path**. Use it to push and deploy container images.

## Typical Workflow

### 1. Get Your Image Repository Path

Your platform team provides:
```
workspace_id: my-workspace
project_id:   hello-api
tenant_id:    dev
app_name:     hello-api
```

The building block computes:
```
registry.onstackit.cloud/platform-demo/my-workspace/hello-api/dev/hello-api
```

### 2. Build Your Container Image

```bash
docker build -t my-hello-api:latest .
```

### 3. Tag and Push to the Registry

Replace `<image_repository>` with your path from step 1:

```bash
# Tag with version
docker tag my-hello-api:latest <image_repository>:v1.0.0

# Push to Harbor
docker push <image_repository>:v1.0.0
```

**Example (actual command):**
```bash
docker tag my-hello-api:latest registry.onstackit.cloud/platform-demo/my-workspace/hello-api/dev/hello-api:v1.0.0
docker push registry.onstackit.cloud/platform-demo/my-workspace/hello-api/dev/hello-api:v1.0.0
```

### 4. Deploy via app-env-config Building Block

Reference your image in the `app-env-config` module:

```hcl
inputs = {
  image_repository = "<image_repository>"
  image_tag        = "v1.0.0"
}
```

The deployment system automatically pulls from Harbor and runs your image.

## Harbor Authentication

Your platform team handles authentication via a **Harbor robot account secret** in your namespace.

No manual credential setup required — everything is automated.

## Troubleshooting

**Q: "Docker push fails — 401 Unauthorized"**  
A: Check with your platform team that Harbor robot credentials are configured in your namespace.

**Q: "How do I know what tag to use?"**  
A: Follow semantic versioning: `v1.0.0`, `v1.0.1`, etc. Git commit SHA also works: `abc1234`.

**Q: "Can I use digest instead of tag?"**  
A: Yes. Use `@sha256:...` for immutable production deployments.

## Copy-Paste Template

```bash
# Set your image repository (ask your platform team)
IMAGE_REPO="registry.onstackit.cloud/platform-demo/<workspace>/<project>/<tenant>/<app>"

# Build
docker build -t my-app:latest .

# Tag and push
docker tag my-app:latest ${IMAGE_REPO}:v1.0.0
docker push ${IMAGE_REPO}:v1.0.0

# Now deploy via app-env-config
```

## Related Building Blocks

- [**app-env-config**](../app-env-config/README.md) — Deploy your image to Kubernetes
- [**namespace-with-argocd**](../namespace-with-argocd/README.md) — Set up GitOps and secrets
