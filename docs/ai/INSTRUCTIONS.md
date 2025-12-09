# AI Assistant Instructions - STACKIT IDP Platform

You are helping develop a **STACKIT Internal Developer Platform** using **Terragrunt + Terraform** and **meshStack Building Blocks**. Follow established conventions and keep code clean, modular, and well-documented.

## Platform Architecture

This platform uses **Terragrunt** for orchestration with the following structure:

```
platform/
  terragrunt.hcl              # Root: S3 backend config + common vars
  01-ske/                     # STACKIT Kubernetes Engine cluster
  02-harbor/                  # Harbor container registry
  03-meshstack/               # meshStack platform integration
  04-argocd/                  # ArgoCD GitOps controller
  building-blocks/
    namespace-with-argocd/    # Reusable building block for namespace provisioning
  namespaces/
    team-a-dev/               # Example namespace instance
    team-b-prod/              # Another namespace instance

app-repo-blueprint/           # Template for application teams
  app/                        # Application code (Python FastAPI demo)
  manifests/                  # Kustomize manifests (base + overlays)
  .github/workflows/          # CI/CD pipeline (GitOps automation)
```

## Key Principles

### 1. Terragrunt-Based Orchestration
- Use Terragrunt for dependency management between platform components
- Each component (`01-ske`, `02-harbor`, etc.) has its own `terragrunt.hcl`
- Dependencies are explicit via `dependency` blocks
- S3 remote state configured in root `terragrunt.hcl`

### 2. Building Block Pattern
- Modules in `building-blocks/` are reusable, self-contained units
- Can be instantiated multiple times (e.g., one namespace per team)
- Follow meshStack Building Block principles
- Export all necessary outputs for consumption

### 3. GitOps-First Deployment
- Applications use **ArgoCD** for deployment (NOT direct kubectl/Helm)
- GitHub Actions builds images and **updates Git manifests**
- ArgoCD watches Git and syncs to cluster
- No cluster credentials in CI pipelines

### 4. Clean Separation of Concerns
- **Platform layer** (`platform/`): Shared infrastructure (cluster, registry, ArgoCD)
- **Building blocks** (`building-blocks/`): Reusable modules for self-service
- **App teams** (`app-repo-blueprint/`): Application code + manifests

## Terraform/Terragrunt Style Guidelines

### Code Style
```hcl
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace_name
    labels = {
      "meshstack.io/tenant" = var.tenant_id
    }
  }
}
```

- **Never** use one-line blocks
- Always use multi-line HCL syntax
- Add inline comments explaining **why**, not what
- Use clear, descriptive variable names
- All code and comments in **English**

### Module Design
- Small, composable modules
- Explicit inputs via `variables.tf`
- Clear outputs via `outputs.tf`
- No hardcoded values (use variables)
- No side effects beyond module scope

### Dependency Management
```hcl
dependency "harbor" {
  config_path = "../../02-harbor"
}

inputs = {
  registry_url = dependency.harbor.outputs.registry_url
}
```

- Use Terragrunt `dependency` blocks (not `terraform_remote_state`)
- Rely on implicit dependencies through outputs (avoid `depends_on`)
- Never reference other modules by path

## Platform Component Responsibilities

### 01-ske (SKE Cluster)
- Provisions STACKIT Kubernetes Engine cluster
- Exports kubeconfig, cluster endpoint, CA certificate
- Does NOT configure anything inside the cluster

### 02-harbor (Container Registry)
- Provisions Harbor registry instance
- Creates shared project (`platform-demo`)
- Creates robot account for image push/pull
- Exports registry URL and credentials

### 03-meshstack (meshStack Integration)
- Configures meshStack platform connection
- Sets up tenant/project mappings
- Exports meshStack metadata

### 04-argocd (GitOps Controller)
- Installs ArgoCD via Helm
- Configures admin credentials
- Exports ArgoCD server URL
- Does NOT create Application CRs (done by building blocks)

### building-blocks/namespace-with-argocd
- Creates Kubernetes namespace with meshStack labels
- Creates resource quotas and network policies
- Creates Harbor pull secret
- Creates ArgoCD Application CR pointing to team's Git repo
- Fully self-contained (can be instantiated many times)

## Application Team Workflow

### Blueprint Structure
```
app-repo-blueprint/
  app/
    main.py                   # FastAPI application
    Dockerfile                # Container build
  manifests/
    base/
      deployment.yaml         # Base K8s resources
      kustomization.yaml      # Kustomize config with image refs
    overlays/
      dev/                    # Dev environment customizations
      prod/                   # Prod environment customizations
  .github/workflows/
    build-push.yaml           # CI: build → push → update manifest → commit
```

### GitOps Flow
1. Developer pushes code to `main`
2. GitHub Actions:
   - Builds Docker image with Git SHA tag
   - Pushes to Harbor registry
   - Updates `manifests/base/kustomization.yaml` with new image tag
   - Commits and pushes manifest change
3. ArgoCD:
   - Detects Git change
   - Syncs to cluster
   - Rolling update with new image

### Key Files

**`.github/workflows/build-push.yaml`:**
- Builds image: `registry.onstackit.cloud/platform-demo/app:main-abc123`
- Runs `kustomize edit set image` to update manifest
- Commits manifest change to Git

**`manifests/base/kustomization.yaml`:**
```yaml
images:
  - name: APP_IMAGE
    newName: registry.onstackit.cloud/platform-demo/app
    newTag: main-abc123  # Updated by CI
```

## Decision Records (ADRs)

### ADR-001: Harbor Registry Strategy
- **Decision:** One shared Harbor project per environment (not per app)
- **Rationale:** Simplifies demo setup, reduces complexity
- **Future:** May evolve to per-team or per-app projects

### ADR-002: Bootstrap Platform Components
- **Decision:** Split into Provision (infrastructure) and Configuration (in-cluster setup)
- **Note:** Current platform uses Terragrunt, ADR-002 references are legacy

## Common Tasks

### Deploy Platform
```bash
cd platform
export STACKIT_PROJECT_ID="..."
export STACKIT_SERVICE_ACCOUNT_KEY_PATH="..."
export HARBOR_USERNAME="admin"
export HARBOR_CLI_SECRET="..."
terragrunt run-all apply
```

### Provision Namespace for Team
```bash
cd platform/namespaces/team-a-dev
terragrunt apply
```

### Setup App Repository
```bash
cp -r app-repo-blueprint team-a-app
cd team-a-app
# Configure GitHub secrets: HARBOR_USERNAME, HARBOR_PASSWORD, HARBOR_PROJECT
git push origin main
# CI runs automatically → ArgoCD syncs
```

## When Making Changes

### Adding a New Platform Component
1. Create `platform/05-newcomponent/` directory
2. Add `terragrunt.hcl` with dependencies
3. Create `module/` subdirectory with `main.tf`, `variables.tf`, `outputs.tf`
4. Update `platform/README.md` with component description
5. Export outputs for consumption by building blocks

### Creating a New Building Block
1. Create `platform/building-blocks/new-block/` directory
2. Write self-contained Terraform module
3. Accept inputs via variables (no hardcoded values)
4. Export all necessary outputs
5. Add `README.md` explaining usage
6. Instantiate in `platform/namespaces/` for testing

### Updating App Blueprint
1. Test changes in `app-repo-blueprint/`
2. Ensure CI workflow works end-to-end
3. Verify ArgoCD sync after manifest update
4. Update `app-repo-blueprint/README.md` with instructions

## Security & Best Practices

- **No secrets in Git:** Use environment variables or secret managers
- **Least privilege:** ServiceAccounts have minimal required permissions
- **Network policies:** Default-deny in all namespaces
- **Resource quotas:** Prevent resource exhaustion
- **Image scanning:** Harbor vulnerability scanning enabled
- **GitOps audit trail:** Every deployment = Git commit

## Tools & References

- **STACKIT Provider:** https://registry.terraform.io/providers/stackitcloud/stackit/latest
- **Terragrunt Docs:** https://terragrunt.gruntwork.io/docs/
- **ArgoCD Docs:** https://argo-cd.readthedocs.io/
- **Kustomize Docs:** https://kustomize.io/

## Response Guidelines

When implementing changes:
1. Ask for clarification before making architectural decisions
2. Follow existing patterns and conventions
3. Keep modules small and focused
4. Write inline comments explaining **why**, not what
5. Test changes locally before committing
6. Update documentation when changing behavior

If a requested change violates platform principles, explain why and propose an alternative.
