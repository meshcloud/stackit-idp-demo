# Building Block: Namespace with ArgoCD Integration

This module configures an **existing** Kubernetes namespace with:
- Resource quotas and limits
- Network policies (default-deny)
- Harbor registry pull secret
- ArgoCD Application for GitOps
- RBAC for ArgoCD to manage the namespace

**Important:** This building block expects the namespace to already exist (typically created by meshStack workspace provisioning). It adds configuration and integrations to the existing namespace rather than creating a new one.

## Usage

### From meshStack Building Block

```hcl
module "team_namespace" {
  source = "../../building-blocks/namespace-with-argocd"

  namespace_name = "team-a-dev"
  tenant_name    = "team-a"
  project_name   = "dev"

  github_repo_url        = "https://github.com/your-org/team-a-app"
  github_target_revision = "main"
  github_manifests_path  = "manifests/overlays/dev"

  harbor_robot_username = var.harbor_robot_username
  harbor_robot_token    = var.harbor_robot_token

  resource_quota_cpu    = "4"
  resource_quota_memory = "8Gi"
}
```

### Standalone Usage

```hcl
provider "kubernetes" {
  config_path = "~/.kube/config"
}

module "namespace" {
  source = "./building-blocks/namespace-with-argocd"

  namespace_name         = "my-app"
  github_repo_url        = "https://github.com/myorg/my-app"
  harbor_robot_username  = var.harbor_username
  harbor_robot_token     = var.harbor_token
}
```

## What Gets Configured

This building block assumes the namespace already exists and adds:

1. **Labels** on the existing namespace (meshStack tenant/project, ArgoCD managed)
2. **ResourceQuota** to limit resource usage
3. **LimitRange** to set default pod limits
4. **NetworkPolicies** (default-deny ingress/egress)
5. **Harbor Pull Secret** (if credentials provided)
6. **ArgoCD Application** (if repo URL provided)
7. **RBAC** for ArgoCD to manage resources

## Prerequisites

- **Namespace must already exist** in the cluster (created by meshStack or manually)
- ArgoCD must be installed and running
- Harbor registry must be accessible (if using pull secrets)

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `namespace_name` | Namespace name | required |
| `github_repo_url` | GitHub repo for ArgoCD | "" |
| `github_manifests_path` | Path to manifests | "manifests/overlays/dev" |
| `harbor_robot_username` | Harbor robot account | "" |
| `resource_quota_cpu` | CPU quota | "4" |
| `argocd_auto_sync` | Enable auto-sync | true |

## Outputs

| Name | Description |
|------|-------------|
| `namespace_name` | Created namespace |
| `argocd_application_name` | ArgoCD app name |
| `harbor_pull_secret_name` | Pull secret name |
