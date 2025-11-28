# STACKIT IDP Platform - Terragrunt Structure

Complete Internal Developer Platform on STACKIT infrastructure using Terragrunt, ArgoCD, and meshStack.

## Architecture

### Repository Structure

```
stackit-idp-demo/
├── platform/                           # THIS REPO - Platform Infrastructure
│   ├── terragrunt.hcl                 # Root config + S3 backend
│   ├── 01-ske/                        # SKE Kubernetes cluster
│   ├── 02-harbor/                     # Harbor container registry
│   ├── 03-meshstack/                  # meshStack platform integration
│   ├── 04-argocd/                     # ArgoCD GitOps controller
│   └── building-blocks/
│       └── namespace-with-argocd/     # Namespace provisioning module
├── app-repo-blueprint/                # Template for app teams
│   ├── app/                           # Python FastAPI application
│   ├── manifests/                     # Kubernetes manifests
│   └── .github/workflows/             # CI/CD pipeline
└── demo/terraform/                    # Legacy bootstrap (deprecated)
```

### Component Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Platform Layer (Terragrunt)                                │
│  ┌──────────┐  ┌─────────┐  ┌───────────┐  ┌─────────┐    │
│  │ 01-SKE   │→ │02-Harbor│→ │03-meshStack│→ │04-ArgoCD│    │
│  │ Cluster  │  │Registry │  │Integration │  │GitOps   │    │
│  └──────────┘  └─────────┘  └───────────┘  └─────────┘    │
│                                    ↓                         │
│                       ┌────────────────────────┐            │
│                       │ Building Block Module  │            │
│                       │ namespace-with-argocd  │            │
│                       └────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────┐
│  App Team Workflow                                           │
│                                                              │
│  ┌──────────────┐    GitHub Actions    ┌──────────────┐    │
│  │ GitHub Repo  │  ─────────────────→  │ Harbor       │    │
│  │ (app code +  │   Build & Push Image │ (container   │    │
│  │  manifests)  │                      │  registry)   │    │
│  └──────────────┘                      └──────────────┘    │
│        ↓                                       ↓             │
│  ┌──────────────┐                      ┌──────────────┐    │
│  │ ArgoCD       │  ←───────────────    │ SKE Cluster  │    │
│  │ (watches     │   Pulls manifests    │ (pulls image)│    │
│  │  manifests)  │                      │              │    │
│  └──────────────┘                      └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

1. **STACKIT Credentials**
   ```bash
   export STACKIT_PROJECT_ID="your-project-id"
   export STACKIT_SERVICE_ACCOUNT_KEY_PATH="~/.stackit/sa-key.json"
   ```

2. **Harbor Credentials**
   ```bash
   export HARBOR_USERNAME="admin"
   export HARBOR_CLI_SECRET="your-harbor-password"
   ```

3. **Install Tools**
   ```bash
   brew install terragrunt terraform
   ```

### Deploy Platform

```bash
cd platform

terragrunt run-all plan
terragrunt run-all apply

cd 01-ske && terragrunt output -raw kube_host
cd ../04-argocd && terragrunt output
```

### Onboard Application Team

#### 1. Platform Team: Provision Namespace

Create `platform/namespaces/team-a-dev/terragrunt.hcl`:

```hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../building-blocks/namespace-with-argocd"
}

dependency "ske" {
  config_path = "../../01-ske"
}

dependency "harbor" {
  config_path = "../../02-harbor"
}

dependency "argocd" {
  config_path = "../../04-argocd"
}

inputs = {
  namespace_name = "team-a-dev"
  tenant_name    = "team-a"
  project_name   = "dev"

  github_repo_url        = "https://github.com/your-org/team-a-app"
  github_target_revision = "main"
  github_manifests_path  = "manifests/overlays/dev"

  harbor_robot_username = dependency.harbor.outputs.robot_username
  harbor_robot_token    = dependency.harbor.outputs.robot_token

  resource_quota_cpu    = "4"
  resource_quota_memory = "8Gi"
}
```

```bash
cd namespaces/team-a-dev
terragrunt apply
```

This creates:
- ✅ Namespace with quotas
- ✅ Harbor pull secret
- ✅ ArgoCD Application
- ✅ Network policies

#### 2. App Team: Create Repository

```bash
# Use the blueprint
cp -r app-repo-blueprint team-a-app
cd team-a-app
git init
git remote add origin https://github.com/your-org/team-a-app
```

Configure GitHub secrets:
- `HARBOR_USERNAME`
- `HARBOR_PASSWORD`
- `HARBOR_PROJECT` (e.g., `team-a`)

Edit manifests:
```bash
# Update manifests/overlays/dev/kustomization.yaml
sed -i 's/NAMESPACE_NAME/team-a-dev/g' manifests/overlays/dev/kustomization.yaml
sed -i 's/HARBOR_PROJECT/team-a/g' manifests/overlays/dev/kustomization.yaml
```

Push to GitHub:
```bash
git add .
git commit -m "Initial commit"
git push -u origin main
```

#### 3. Automatic Deployment

- GitHub Actions builds image → pushes to Harbor
- ArgoCD detects manifest changes → syncs to namespace
- Application runs on SKE cluster

## meshStack Integration

### Building Block Pattern

When teams order a namespace via meshStack, the Building Block Terraform runs:

```hcl
module "namespace" {
  source = "../../building-blocks/namespace-with-argocd"

  namespace_name = meshstack_workspace.id
  tenant_name    = meshstack_tenant.id
  project_name   = meshstack_project.id

  github_repo_url        = var.team_github_repo
  harbor_robot_username  = harbor_robot.username
  harbor_robot_token     = harbor_robot.token
}
```

This provides self-service namespace provisioning with:
- Automated GitOps setup
- Pre-configured registry access
- Resource governance (quotas/limits)
- Network isolation

## State Management

All Terraform state stored in S3:
- **Bucket**: `tfstate-meshstack-backend`
- **Endpoint**: `https://object.storage.eu01.onstackit.cloud`
- **Region**: `eu01`
- **Encryption**: Enabled

State layout:
```
tfstate-meshstack-backend/
├── 01-ske/terraform.tfstate
├── 02-harbor/terraform.tfstate
├── 03-meshstack/terraform.tfstate
├── 04-argocd/terraform.tfstate
└── namespaces/team-a-dev/terraform.tfstate
```

## Advantages Over Old Bootstrap Structure

| Old (demo/terraform/bootstrap) | New (platform/) |
|-------------------------------|-----------------|
| 3-layer Makefile orchestration | Terragrunt dependency graph |
| Manual state management | Centralized S3 backend |
| Hardcoded paths | Dynamic module resolution |
| No building blocks | Reusable namespace module |
| Manual namespace setup | Automated GitOps integration |

## Security Best Practices

1. **Secrets Management**
   - Use environment variables for credentials
   - Never commit secrets to Git
   - Rotate Harbor robot accounts regularly

2. **Network Policies**
   - Default-deny ingress/egress
   - Teams add explicit allow rules

3. **Resource Quotas**
   - CPU/Memory limits enforced
   - Pod count restrictions

4. **RBAC**
   - Namespace-scoped permissions
   - ArgoCD service account for deployments
   - Platform team has cluster-admin

## Troubleshooting

### ArgoCD Not Syncing

```bash
kubectl get applications -n argocd
kubectl describe application team-a-dev -n argocd
```

### Harbor Pull Failures

```bash
kubectl get secret harbor-pull-secret -n team-a-dev -o yaml
kubectl describe pod <pod-name> -n team-a-dev
```

### Check Platform Status

```bash
cd platform
terragrunt run-all output
```

## Next Steps

1. **Add ApplicationSet** for auto-discovery of team namespaces
2. **Integrate with meshStack API** for automated provisioning
3. **Add Ingress controller** for external access
4. **Implement backup strategy** for GitOps state
5. **Add monitoring** (Prometheus/Grafana)

## Support

- Platform Team: platform-team@example.com
- Documentation: https://platform-docs.example.com
- meshStack Portal: https://meshstack.example.com
