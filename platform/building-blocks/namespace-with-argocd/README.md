# Building Block: Namespace with ArgoCD Integration

This module configures an **existing** Kubernetes namespace with:
- Labels (meshStack tenant/project, managed-by)
- Harbor registry pull secret
- ArgoCD Application for GitOps
- Optional: Argo Workflows EventSource + Sensor for CI/CD
- Optional: External LoadBalancer service for app access

**Important:** This building block expects the namespace to already exist (typically created by meshStack workspace provisioning). It adds configuration and integrations to the existing namespace rather than creating a new one.

## Features

- Auto-generates Git repository URL from `gitea_username` and `app_name`
- Auto-generates Harbor image name from `harbor_url` and `app_name`
- Simplified configuration with sensible defaults
- Optional Argo Workflows integration for automated builds
- Optional external LoadBalancer for app access

## Usage

### Basic Configuration (meshStack Building Block)

```hcl
module "team_namespace" {
  source = "../../building-blocks/namespace-with-argocd"

  namespace_name = "team-a-dev"
  app_name       = "team-a-app"
  gitea_username = "myuser"

  harbor_robot_username = var.harbor_robot_username
  harbor_robot_token    = var.harbor_robot_token
}
```

This creates:
- Labels on existing namespace
- Harbor pull secret
- ArgoCD Application pointing to `https://git-service.git.onstackit.cloud/myuser/team-a-app.git`
- Uses image: `registry.onstackit.cloud/registry/team-a-app`

### With Argo Workflows CI/CD

```hcl
module "team_namespace" {
  source = "../../building-blocks/namespace-with-argocd"

  namespace_name = "my-app"
  app_name       = "my-app"
  gitea_username = "myuser"
  gitea_token    = var.gitea_token

  harbor_robot_username = var.harbor_robot_username
  harbor_robot_token    = var.harbor_robot_token

  enable_argo_workflows = true
  expose_app_externally = true
  external_port         = 8080
}
```

This additionally creates:
- Argo Workflows EventSource (webhook listener)
- Argo Workflows Sensor (triggers build on push)
- ServiceAccount and RoleBinding for workflow execution
- External LoadBalancer for app access

### Standalone Usage

```hcl
provider "kubernetes" {
  config_path = "~/.kube/config"
}

module "namespace" {
  source = "./building-blocks/namespace-with-argocd"

  namespace_name         = "my-app"
  app_name               = "my-app"
  gitea_username         = "myuser"
  harbor_robot_username  = var.harbor_username
  harbor_robot_token     = var.harbor_token
}
```

## What Gets Configured

This building block assumes the namespace already exists and adds:

1. **Labels** on the existing namespace:
   - `app.kubernetes.io/managed-by = "terraform"`
   - `meshstack.io/tenant = <tenant_name>`
   - `meshstack.io/project = <project_name>`
   - `argocd.argoproj.io/managed = "true"`
   - `environment = "dev"` (default, can override with `labels` variable)

2. **Harbor Pull Secret** (if credentials provided)
   - Name: `harbor-pull-secret`
   - Type: `kubernetes.io/dockerconfigjson`

3. **ArgoCD Application**
   - Name: `<namespace_name>`
   - Source: Auto-generated from `gitea_username` and `app_name`
   - Path: `manifests/overlays/dev` (configurable)
   - Auto-sync enabled by default

4. **Argo Workflows Resources** (if `enable_argo_workflows = true`):
   - EventSource (webhook listener on external LoadBalancer)
   - Sensor (triggers WorkflowTemplate on Git push)
   - ServiceAccount with permissions
   - RoleBinding for workflow execution

5. **External Service** (if `expose_app_externally = true`):
   - LoadBalancer service for app access
   - Configurable external port

## Auto-Generated Values

The building block auto-generates these values to reduce configuration:

- **Git Repository URL**: `https://git-service.git.onstackit.cloud/<gitea_username>/<app_name>.git`
- **Harbor Image Name**: `<harbor_url>/registry/<app_name>`
- **Tenant Name**: Defaults to `app_name` if not specified
- **Project Name**: Defaults to `app_name` if not specified
- **App Selector Labels**: `app.kubernetes.io/name = <app_name>`

## Prerequisites

- **Namespace must already exist** in the cluster (created by meshStack or manually)
- ArgoCD must be installed and running
- Harbor registry must be accessible (if using pull secrets)
- Argo Workflows must be installed (if using `enable_argo_workflows = true`)

## Inputs

| Name | Description | Default | Required |
|------|-------------|---------|----------|
| `namespace_name` | Namespace name (must exist) | - | yes |
| `app_name` | Application name (used for auto-generation) | `namespace_name` | no |
| `gitea_username` | STACKIT Git username | - | yes (if using ArgoCD) |
| `gitea_token` | STACKIT Git token | `""` | no (required for Argo Workflows) |
| `harbor_url` | Harbor registry URL | `registry.onstackit.cloud` | no |
| `harbor_robot_username` | Harbor robot account | `""` | no |
| `harbor_robot_token` | Harbor robot token | `""` | no |
| `git_target_revision` | Git branch/tag | `"main"` | no |
| `git_manifests_path` | Path to manifests | `"manifests/overlays/dev"` | no |
| `argocd_namespace` | ArgoCD namespace | `"argocd"` | no |
| `argocd_auto_sync` | Enable auto-sync | `true` | no |
| `enable_argo_workflows` | Enable CI/CD pipeline | `false` | no |
| `argo_workflows_namespace` | Argo Workflows namespace | `"argo-workflows"` | no |
| `expose_app_externally` | Expose via LoadBalancer | `false` | no |
| `external_port` | External port | `8080` | no |
| `app_target_port` | App container port | `8000` | no |
| `tenant_name` | meshStack tenant | `<app_name>` | no |
| `project_name` | meshStack project | `<app_name>` | no |
| `labels` | Additional namespace labels | `{environment="dev", managed-by="terraform"}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `namespace_name` | Namespace name |
| `namespace_labels` | Namespace labels |
| `argocd_application_name` | ArgoCD application name |
| `harbor_pull_secret_name` | Pull secret name (sensitive) |
| `argo_workflows_webhook_url` | Webhook URL for Git integration |
| `argo_workflows_webhook_ip` | Webhook IP address |
| `external_service_ip` | App external IP (if exposed) |
| `external_service_url` | App external URL (if exposed) |
| `summary` | Summary with next steps |

## Integration with Git Repository Building Block

Combine with the `stackit-git-repo` building block for full automation:

```hcl
module "namespace" {
  source = "./building-blocks/namespace-with-argocd"
  
  namespace_name         = "my-app"
  app_name               = "my-app"
  gitea_username         = "myuser"
  gitea_token            = var.gitea_token
  enable_argo_workflows  = true
  expose_app_externally  = true
  harbor_robot_username  = var.harbor_robot_username
  harbor_robot_token     = var.harbor_robot_token
}

module "repo" {
  source = "./building-blocks/stackit-git-repo"
  
  gitea_base_url     = "https://git-service.git.onstackit.cloud"
  gitea_token        = var.gitea_token
  gitea_username     = "myuser"
  gitea_organization = "my-org"
  repository_name    = "my-app"
  webhook_url        = module.namespace.argo_workflows_webhook_url
  
  use_template       = true
  template_owner     = "likvid"
  template_name      = "app-template-python"
  template_repo_name = "my-app"
  template_namespace = "my-app"
}
```

## Notes

- Namespace must exist before running this module
- Git repository URL is auto-generated - ensure it matches your actual repo
- Harbor image name uses `/registry/` project by default
- Argo Workflows webhook requires external LoadBalancer IP assignment
- App selector labels use `app.kubernetes.io/name` convention
