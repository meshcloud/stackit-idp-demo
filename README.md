# STACKIT IDP Platform Demo

Complete Internal Developer Platform on STACKIT infrastructure using Terragrunt, ArgoCD, Argo Workflows, and meshStack.

## Overview

This repository demonstrates a production-ready IDP platform with:
- **Infrastructure as Code**: Terragrunt modules for STACKIT SKE cluster, ArgoCD, and Argo Workflows
- **Self-Service Building Blocks**: meshStack integration for automated provisioning
- **GitOps Delivery**: ArgoCD for continuous deployment
- **CI/CD Pipeline**: Argo Workflows triggered by STACKIT Git webhooks
- **App Template**: Python FastAPI starter with automated builds

## Architecture

### Repository Structure

```
stackit-idp-demo/
├── platform/                           # Platform Infrastructure (Terragrunt)
│   ├── root.hcl                       # Root config + S3 backend
│   ├── 00-state-bucket/               # ⚠️ DEPLOY FIRST - Creates S3 bucket
│   ├── 01-ske/                        # SKE Kubernetes cluster
│   ├── 02-meshstack/                  # meshStack platform integration
│   ├── 03-argocd/                     # ArgoCD GitOps controller
│   ├── 04-argo-workflows/             # Argo Workflows + EventSource
│   └── building-blocks/
│       ├── stackit-git-repo/          # Git repository provisioning
│       └── namespace-with-argocd/     # Namespace + ArgoCD app provisioning
├── app-template-python/               # Template for application teams
│   ├── app/                           # Python FastAPI application
│   ├── manifests/                     # Kubernetes manifests (Kustomize)
│   └── .gitea/                        # Template variables
└── docs/                              # Documentation
```

### Platform Infrastructure Flow

```mermaid
graph LR
    A[00-StateBucket] --> B[01-SKE]
    B --> C[02-meshStack]
    C --> D[03-ArgoCD]
    D --> E[04-Argo Workflows]
    E --> F[Building Blocks]
```

### App Team Workflow

```mermaid
graph LR
    A[Git Push] --> B[Webhook]
    B --> C[Argo Workflow]
    C --> D[Harbor]
    D --> E[ArgoCD]
    E --> F[Kubernetes]
```

## meshStack Building Blocks

This platform provides two building blocks that run in **meshcloud-demo**:

### 1. `stackit-git-repo` - Git Repository Provisioning

Creates a STACKIT Git repository from the `app-template-python` template.

**Inputs:**
- `gitea_username`: Your STACKIT Git username
- `gitea_organization`: Your STACKIT Git organization
- `repository_name`: Name for the new repository
- `template_repo_name`: Repository name for template substitution
- `template_namespace`: Kubernetes namespace for template substitution
- `webhook_url`: (Optional) Argo Workflows webhook URL

**Outputs:**
- Repository URLs (HTML, Clone, SSH)
- Summary with next steps for developers

**What it creates:**
- Git repository from template with variable substitution
- Webhook configuration (if enabled)
- Ready-to-use Python FastAPI application

### 2. `namespace-with-argocd` - Kubernetes Namespace + GitOps

Creates a Kubernetes namespace with ArgoCD application and optional Argo Workflows integration.

**Inputs:**
- `namespace_name`: Name of the namespace
- `app_name`: Application name (used for deriving defaults)
- `gitea_username`: STACKIT Git username (for repo URL construction)
- `harbor_robot_username` / `harbor_robot_token`: Harbor credentials
- `enable_argo_workflows`: Enable CI/CD pipeline (default: false)
- `expose_app_externally`: Expose app via LoadBalancer (default: false)

**Outputs:**
- Namespace details
- ArgoCD application name
- External URLs (app and webhook)
- Summary with deployment instructions

**What it creates:**
- Labeled Kubernetes namespace
- Harbor pull secret
- ArgoCD Application (GitOps)
- Optional: Argo Workflows EventSource, Sensor, ServiceAccount, RoleBinding
- Optional: External LoadBalancer service

## Quick Start

### Prerequisites

```bash
# Install tools
brew install terragrunt terraform

# Configure STACKIT credentials
export STACKIT_PROJECT_ID="your-project-id"
export STACKIT_SERVICE_ACCOUNT_KEY_PATH="~/.stackit/sa-key.json"
```

### Deploy Platform

**Step 1: Create State Bucket**
```bash
cd platform/00-state-bucket
terragrunt init
terragrunt apply

# Save credentials
export AWS_ACCESS_KEY_ID=$(terragrunt output -raw access_key_id)
export AWS_SECRET_ACCESS_KEY=$(terragrunt output -raw secret_access_key)
```

**Step 2: Deploy Platform Modules**
```bash
cd ..
terragrunt run-all plan
terragrunt run-all apply
```

**Step 3: Get Cluster Access**
```bash
cd 01-ske
terragrunt output -raw kubeconfig > ~/.kube/stackit-config
export KUBECONFIG=~/.kube/stackit-config
kubectl get nodes
```

### Use Building Blocks (via meshStack)

Once deployed, teams can self-service provision via meshStack portal:

1. **Order Git Repository**
   - Select `stackit-git-repo` building block
   - Provide repository name and namespace
   - Receive ready-to-use Git repository with template code

2. **Order Kubernetes Namespace**
   - Select `namespace-with-argocd` building block
   - Provide namespace name and Git repository URL
   - Receive fully configured namespace with GitOps pipeline

3. **Start Developing**
   - Clone your repository
   - Edit `app/main.py`
   - Push changes
   - Automated build and deployment via Argo Workflows + ArgoCD

## State Management

All Terraform state stored in STACKIT S3:
- **Bucket**: `tfstate-meshstack-backend`
- **Endpoint**: `https://object.storage.eu01.onstackit.cloud`
- **Region**: `eu01`
- **Encryption**: Enabled

## Security

- Namespace-scoped RBAC
- Harbor pull secrets for private images
- Webhook authentication for Argo Workflows
- Secrets via environment variables (never committed)
- Template variable substitution in Git repos

## Documentation

- [Cluster Access Operations](docs/CLUSTER_ACCESS_OPERATIONS.md)
- [Architecture Deep Dive](docs/stackit-idp-architecture.md)
- [ADR: Harbor Registry Strategy](docs/adr/ADR-001_harbor-registry-strategy.md)

## Building Block README Files

For application teams using the building blocks:
- [Git Repository Building Block](platform/building-blocks/stackit-git-repo/APP_TEAM_README.md)
- [Namespace Building Block](platform/building-blocks/namespace-with-argocd/APP_TEAM_README.md)

## Support

This is a demo platform showcasing STACKIT IDP capabilities with meshStack integration.

For production deployments, consider:
- Ingress controller for domain-based routing
- Monitoring (Prometheus/Grafana)
- Backup strategy for GitOps state
- ApplicationSets for auto-discovery
- Advanced RBAC and network policies
