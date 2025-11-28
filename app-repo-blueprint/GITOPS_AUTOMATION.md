# GitOps Automation Setup

This repository implements the **recommended ArgoCD GitOps pattern** for automated deployments.

## How It Works

### Traditional (Non-GitOps) Approach ❌
```
CI builds image → Push to registry → CI deploys directly to cluster (kubectl apply)
```
Problems:
- Git doesn't reflect deployed state
- No audit trail
- Hard to rollback
- Requires cluster credentials in CI

### Our GitOps Approach ✅
```
CI builds image → Push to registry → CI updates Git manifest → ArgoCD syncs to cluster
```
Benefits:
- Git is single source of truth
- Full audit trail in Git history
- Easy rollback with git revert
- No cluster credentials in CI pipeline

## Implementation Details

### 1. GitHub Actions Workflow
**File:** `.github/workflows/build-push.yaml`

**What it does:**
1. Builds Docker image with SHA tag (e.g., `main-abc123`)
2. Pushes to Harbor registry
3. Updates `manifests/base/kustomization.yaml` with new image tag using Kustomize
4. Commits and pushes manifest change back to Git

**Key additions:**
```yaml
permissions:
  contents: write  # Allows workflow to commit back to repo

steps:
  - name: Setup Kustomize
    uses: imranismail/setup-kustomize@v2
  
  - name: Update Kustomize image
    run: |
      cd manifests/base
      kustomize edit set image <registry>/<project>/<image>=<registry>/<project>/<image>:main-<sha>
  
  - name: Commit and push manifest
    run: |
      git config user.name "github-actions[bot]"
      git add manifests/base/kustomization.yaml
      git commit -m "Update image to main-<sha>"
      git push
```

### 2. Kustomize Configuration
**File:** `manifests/base/kustomization.yaml`

**Added section:**
```yaml
images:
  - name: registry.onstackit.cloud/HARBOR_PROJECT/platform-demo
    newTag: latest  # CI updates this with actual SHA tag
```

This tells Kustomize to replace the image reference in `deployment.yaml` with the specified tag.

### 3. How Kustomize Image Transformation Works

**Original deployment.yaml:**
```yaml
spec:
  containers:
    - name: app
      image: registry.onstackit.cloud/HARBOR_PROJECT/platform-demo:latest
```

**After `kustomize edit set image ... newTag: main-abc123`:**
```yaml
# kustomization.yaml
images:
  - name: registry.onstackit.cloud/HARBOR_PROJECT/platform-demo
    newTag: main-abc123
```

**When ArgoCD applies with Kustomize:**
```yaml
spec:
  containers:
    - name: app
      image: registry.onstackit.cloud/HARBOR_PROJECT/platform-demo:main-abc123
```

## Complete Flow Example

```bash
# 1. Developer makes code change
echo "new feature" >> app/main.py
git commit -am "Add new feature"
git push origin main

# 2. GitHub Actions runs (automatically)
# - Builds image: registry.onstackit.cloud/myproject/platform-demo:main-7a3f8c2
# - Pushes to Harbor
# - Updates manifests/base/kustomization.yaml:
#     images:
#       - name: registry.onstackit.cloud/myproject/platform-demo
#         newTag: main-7a3f8c2
# - Commits: "Update image to main-7a3f8c2"
# - Pushes to Git

# 3. ArgoCD detects Git change (within 3 minutes or via webhook)
# - Sees kustomization.yaml changed
# - Runs: kustomize build manifests/base
# - Applies to Kubernetes namespace

# 4. Kubernetes performs rolling update
# - Creates new pods with image main-7a3f8c2
# - Terminates old pods
# - Service continues with zero downtime

# ✓ DEPLOYED
```

## Rollback Example

```bash
# Check deployment history
git log --oneline manifests/base/kustomization.yaml

# Rollback to previous version
git revert HEAD
git push

# ArgoCD will automatically sync the rollback
# Kubernetes will roll back to previous image version
```

## Why This is the Standard

According to [ArgoCD documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/ci_automation/):

> "Update the local manifests using your preferred templating tool, and push the changes to Git"

This is the recommended approach because:
1. **Git as source of truth** - deployed state matches Git
2. **Separation of concerns** - CI builds, ArgoCD deploys
3. **Security** - CI doesn't need cluster credentials
4. **Auditability** - Git history shows all deployments
5. **GitOps principles** - declarative, versioned, automated

## References

- [ArgoCD CI Automation Guide](https://argo-cd.readthedocs.io/en/stable/user-guide/ci_automation/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Kustomize Documentation](https://kustomize.io/)
