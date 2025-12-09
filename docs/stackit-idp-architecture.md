# STACKIT Internal Developer Platform Architecture

Complete reference implementation for STACKIT SKE + Harbor + ArgoCD GitOps platform with meshStack integration.

## Architecture Overview

```
meshStack
  └── Platform
       ├── STACKIT SKE Cluster (Kubernetes)
       ├── Harbor Container Registry
       ├── ArgoCD (GitOps Controller)
       └── meshStack Integration
            └── Building Block: namespace-with-argocd
                 ├── Creates Kubernetes Namespace
                 ├── Applies Resource Quotas & Network Policies
                 ├── Creates Harbor Robot Account & Pull Secret
                 └── Creates ArgoCD Application CR
                      └── Points to Team's GitHub Repository

Team Workspace
  └── GitHub Repository (from app-repo-blueprint)
       ├── Application Code
       ├── Kubernetes Manifests (Kustomize)
       └── GitHub Actions CI/CD
            ├── Builds Docker Image
            ├── Pushes to Harbor
            ├── Updates Kustomize Manifest
            └── Commits to Git → ArgoCD Syncs
```

## Key Differences from AKS Reference

| Aspect | AKS Reference | Our STACKIT Implementation |
|--------|---------------|----------------------------|
| **Cloud Provider** | Azure (AKS) | STACKIT (SKE) |
| **Container Registry** | Azure Container Registry (ACR) | Harbor |
| **Deployment Method** | GitHub Actions deploys directly | ArgoCD GitOps (recommended) |
| **CI/CD Pattern** | Imperative (kubectl apply) | Declarative GitOps |
| **Cluster Access** | ServiceAccount + kubeconfig in GitHub | No cluster creds in CI |
| **Repository Creation** | meshStack creates GitHub repo | Teams use blueprint template |
| **Building Block** | GitHub Actions Connector | ArgoCD Application CR |

## GitOps Flow (Our Approach)

### 1. Platform Team Deploys Infrastructure

```bash
cd platform/
terragrunt run-all apply
```

**Creates:**
- SKE Kubernetes cluster
- Harbor container registry
- ArgoCD installation
- meshStack platform integration

### 2. Team Requests Namespace via meshStack

**Building Block Input:**
- Namespace name
- GitHub repository URL
- Harbor project name

**Building Block Creates:**
- Kubernetes namespace with labels
- Resource quotas and limits
- Network policies
- Harbor robot account
- Kubernetes pull secret
- **ArgoCD Application CR** pointing to team's GitHub repo

### 3. Team Uses App Repository Blueprint

**Team clones:** `app-repo-blueprint/`

**Structure:**
```
app/                          # Application code
  ├── main.py                # FastAPI app
  ├── requirements.txt       # Dependencies
  └── Dockerfile             # Container definition

manifests/                    # Kubernetes manifests
  ├── base/                  # Base Kustomize
  │   ├── deployment.yaml
  │   ├── service.yaml
  │   └── kustomization.yaml # Image transformation
  └── overlays/              # Environment-specific
      ├── dev/
      └── prod/

.github/workflows/            # CI/CD pipeline
  └── build-push.yaml        # Build → Harbor → Update Git
```

### 4. Automated Deployment Flow

```
Developer: git push
    ↓
GitHub Actions Workflow:
  1. Checkout code
  2. Build Docker image (tagged with git SHA)
  3. Push to Harbor registry
  4. Run: kustomize edit set image <image>:main-<sha>
  5. Commit manifests/base/kustomization.yaml
  6. Push manifest change to Git
    ↓
Git Repository Updated
    ↓
ArgoCD (polling every 3min or webhook):
  - Detects Git change
  - Runs: kustomize build manifests/base
  - Compares with cluster state
  - Syncs differences
    ↓
Kubernetes:
  - Rolling update deployment
  - Pulls image from Harbor (using pull secret)
  - New pods replace old pods
    ↓
✅ Application Deployed
```

## Platform Components

### 1. STACKIT SKE Cluster

**Module:** `platform/01-ske/`

- Managed Kubernetes on STACKIT
- Multi-node cluster with auto-scaling
- Integrated with STACKIT networking

### 2. Harbor Registry

**Module:** `platform/02-harbor/`

- Container image registry
- Vulnerability scanning
- Robot accounts for automation
- Project-based access control
- Pull secrets injected into namespaces

### 3. meshStack Integration

**Module:** `platform/03-meshstack/`

- Platform registration in meshStack
- Building block definitions
- RBAC and policy mapping

### 4. ArgoCD GitOps Controller

**Module:** `platform/04-argocd/`

- Installed in `argocd` namespace
- ServiceAccount with cluster-admin (for platform)
- Watches Git repositories for manifest changes
- Auto-sync to namespaces
- Web UI for deployment visibility

### 5. Namespace Building Block

**Module:** `platform/building-blocks/namespace-with-argocd/`

**Creates per team:**
```hcl
resource "kubernetes_namespace" "team" {
  metadata {
    name = var.namespace_name
    labels = {
      "meshstack.io/workspace" = var.workspace_id
      "meshstack.io/project"   = var.project_id
    }
  }
}

resource "kubernetes_resource_quota" "team" {
  # CPU, memory, pod limits
}

resource "kubernetes_network_policy" "team" {
  # Namespace isolation
}

resource "kubernetes_secret" "harbor_pull" {
  # Harbor robot account credentials
}

resource "kubectl_manifest" "argocd_application" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: ${var.namespace_name}
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: ${var.github_repo_url}
        targetRevision: main
        path: manifests/base
      destination:
        server: https://kubernetes.default.svc
        namespace: ${var.namespace_name}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML
}
```

## Security Model

### No Cluster Credentials in CI

Unlike the AKS reference which stores kubeconfig in GitHub secrets:

**AKS Approach (we DON'T do this):**
```yaml
# GitHub Actions
- run: kubectl apply -f manifests/
  env:
    KUBECONFIG: ${{ secrets.KUBECONFIG }}  # Cluster admin access!
```

**Our Approach:**
```yaml
# GitHub Actions
- run: |
    kustomize edit set image ...
    git commit && git push
# No kubectl, no cluster access needed!
```

**ArgoCD** has cluster access, not CI/CD pipeline.

### Harbor Robot Accounts

Each namespace gets dedicated Harbor robot account:
- Read-only access to specific project
- Auto-rotated credentials
- Injected as Kubernetes pull secret
- No shared credentials

### Namespace Isolation

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-cross-namespace
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector: {}  # Only same namespace
```

## Operational Workflows

### Deploy New Application

```bash
# Team creates repo from blueprint
git clone https://github.com/org/app-repo-blueprint my-app
cd my-app

# Configure in GitHub repo settings:
# Secrets:
#   HARBOR_PROJECT=my-team
#   HARBOR_USERNAME=robot$my-team-pull
#   HARBOR_PASSWORD=<token>

# Team requests namespace via meshStack portal
# Platform team runs building block:
cd platform/building-blocks/namespace-with-argocd/
terraform apply \
  -var="namespace_name=my-team" \
  -var="github_repo_url=https://github.com/org/my-app" \
  -var="harbor_project=my-team"

# Team develops and pushes
git push origin main

# ✅ Auto-deployed via GitHub Actions → ArgoCD
```

### Update Application

```bash
# Developer makes changes
vim app/main.py
git commit -am "Add feature"
git push

# GitHub Actions:
#   1. Builds image: my-app:main-abc123
#   2. Pushes to Harbor
#   3. Updates kustomization.yaml
#   4. Commits to Git

# ArgoCD:
#   1. Detects Git change
#   2. Syncs to namespace
#   3. Kubernetes rolling update

# ✅ Deployed automatically
```

### Rollback Deployment

```bash
# Check deployment history
git log manifests/base/kustomization.yaml

# Rollback to previous version
git revert HEAD
git push

# ArgoCD syncs rollback automatically
# ✅ Rolled back
```

### Monitor Deployments

```bash
# ArgoCD UI
open https://argocd.ske.example.com

# ArgoCD CLI
argocd app list
argocd app get my-team
argocd app sync my-team --prune

# Kubernetes
kubectl get pods -n my-team
kubectl logs -n my-team -l app=my-app
```

## Why GitOps (Not Direct Deployment)

### Traditional CI/CD (AKS Reference)

```
Code Change → CI builds → CI deploys to cluster
```

**Problems:**
- ❌ CI needs cluster admin credentials
- ❌ No audit trail of what's deployed
- ❌ Git doesn't match cluster state
- ❌ Hard to rollback (need to redeploy old version)
- ❌ Drift: manual changes not tracked

### GitOps (Our Approach)

```
Code Change → CI builds → CI updates Git → ArgoCD syncs
```

**Benefits:**
- ✅ Git is single source of truth
- ✅ CI doesn't need cluster access
- ✅ Full audit trail in Git history
- ✅ Easy rollback (git revert)
- ✅ Drift detection: ArgoCD corrects manual changes
- ✅ Declarative: desired state in Git

## Comparison Table: AKS Reference vs Our Implementation

| Feature | AKS Reference | STACKIT IDP |
|---------|---------------|-------------|
| **Deployment Pattern** | Imperative (CI runs kubectl) | Declarative GitOps (ArgoCD) |
| **Cluster Credentials** | Stored in GitHub Secrets | Not in CI (ArgoCD has access) |
| **Image Tag Strategy** | Hardcoded in manifests | Kustomize transformation |
| **Manifest Updates** | Manual or templating (envsubst) | Kustomize edit + Git commit |
| **Sync Mechanism** | Push (CI applies) | Pull (ArgoCD polls Git) |
| **Rollback** | Redeploy old image | Git revert |
| **Drift Detection** | None | ArgoCD detects & corrects |
| **Audit Trail** | CI logs only | Git history |
| **Source of Truth** | Running cluster state | Git repository |
| **Building Block Creates** | GitHub repo + kubeconfig secret | Namespace + ArgoCD Application |
| **Team Onboarding** | meshStack creates GitHub repo | Team clones blueprint |

## Technology Stack

### Infrastructure
- **STACKIT SKE**: Managed Kubernetes (not AKS)
- **STACKIT S3**: Terraform state backend
- **Terragrunt**: Infrastructure orchestration
- **Terraform**: Infrastructure as Code

### Platform Services
- **Harbor**: Container registry (not ACR)
- **ArgoCD**: GitOps continuous delivery
- **meshStack**: Multi-tenancy & self-service

### Application Layer
- **Kustomize**: Kubernetes manifest management
- **GitHub Actions**: CI pipeline (build only, not deploy)
- **GitHub**: Git repository hosting

## Advantages of Our Approach

### 1. Security
- No cluster credentials in CI/CD
- Least privilege: ArgoCD uses ServiceAccounts
- Robot accounts scoped to single Harbor project

### 2. Auditability
- Every deployment is a Git commit
- Who deployed what, when → Git blame
- Easy compliance reporting

### 3. Reliability
- Declarative: desired state always in Git
- Drift correction: manual changes reverted
- Consistent deployments across environments

### 4. Developer Experience
- Simple: push code, get deployment
- Transparent: see deployment state in ArgoCD UI
- Fast feedback: ArgoCD syncs within 3 minutes

### 5. Platform Team Efficiency
- No debugging CI/CD cluster access issues
- Building blocks are reusable Terraform modules
- Terragrunt handles orchestration

## Future Enhancements

### Planned
- [ ] Git webhooks for instant ArgoCD sync (instead of 3min polling)
- [ ] Progressive delivery with Argo Rollouts
- [ ] Multi-environment support (dev/staging/prod)
- [ ] Sealed Secrets for secure secret management
- [ ] Service mesh integration (Istio/Linkerd)

### Under Consideration
- [ ] ArgoCD ApplicationSets for multi-tenant scaling
- [ ] ArgoCD Notifications (Slack/Teams integration)
- [ ] Cost tracking per namespace/team
- [ ] Developer portal (Backstage integration)

## References

### Official Documentation
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [ArgoCD CI Automation](https://argo-cd.readthedocs.io/en/stable/user-guide/ci_automation/)
- [Kustomize Documentation](https://kustomize.io/)
- [Harbor Documentation](https://goharbor.io/docs/)

### Internal Documentation
- [Platform Deployment Guide](../platform/DEPLOYMENT.md)
- [App Blueprint GitOps Automation](../app-repo-blueprint/GITOPS_AUTOMATION.md)
- [Building Block Usage](../platform/building-blocks/namespace-with-argocd/README.md)

---

**This is NOT an AKS implementation.** This is a STACKIT-native IDP using GitOps best practices with ArgoCD.
