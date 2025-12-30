terraform {
  required_providers {
    gitea = {
      source  = "Lerentis/gitea"
      version = "~> 0.12"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
    }
  }
}

provider "gitea" {
  base_url = var.gitea_base_url
  token    = var.gitea_token
}

# Create the GitOps state repository
resource "gitea_repository" "state_repo" {
  username          = var.gitea_organization
  name              = var.state_repo_name
  description       = "GitOps state repository for STACKIT IDP demo"
  private           = true
  auto_init         = true
  default_branch    = var.default_branch
  issue_labels      = ""
}

# Create local temporary directory for git operations
resource "local_file" "repo_init_script" {
  filename = "${path.module}/.tmp/init-repo.sh"
  content  = <<-EOT
#!/bin/bash
set -e

REPO_DIR="${path.module}/.tmp/repo"
REPO_URL="${gitea_repository.state_repo.clone_url}"
TOKEN="${var.gitea_token}"
BRANCH="${var.default_branch}"

# URL with token embedded for HTTPS clone
REPO_URL_WITH_AUTH="$(echo $REPO_URL | sed "s|https://|https://git:$TOKEN@|")"

# Create repo directory if needed
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

# Initialize git if not already done
if [ ! -d .git ]; then
  git clone "$REPO_URL_WITH_AUTH" . 2>/dev/null || true
fi

# Configure git user (required for commits)
git config user.email "terraform@stackit.cloud"
git config user.name "Terraform Automation"

# Create stable ID directory structure per ADR-004
# Format: workspaces/<workspace-id>/projects/<project-id>/tenants/<tenant-id>/
mkdir -p workspaces/likvid/projects/hello-api/tenants/dev

# Create README.md if it doesn't exist
if [ ! -f README.md ] || [ ! -s README.md ]; then
  cat > README.md << 'EOF'
# STACKIT IDP GitOps State Repository

This repository contains application environment configuration and release state
managed by ArgoCD for the STACKIT Internal Developer Platform.

## Structure

Uses stable identifiers (meshStack IDs) for all directory paths:

```
workspaces/<workspace-id>/
  projects/<project-id>/
    tenants/<tenant-id>/
      app-env.yaml    # Environment configuration (app-team influence)
      release.yaml    # Release state (Release Controller updates this)
```

Example: `workspaces/likvid/projects/hello-api/tenants/dev/`

## Key Principles

- **Stable IDs:** Paths use workspace/project/tenant IDs, not mutable display names
- **Separation of concerns:** app-env.yaml vs release.yaml
- **GitOps source of truth:** All deployment state lives in Git
- **Platform-owned:** Application teams only push images; they don't modify this repo

## GitOps Workflow

1. Platform operator creates app-env.yaml + release.yaml in stable ID directory
2. ArgoCD watches this repository
3. Application team pushes container image to registry
4. Release Controller (future) updates release.yaml with new image
5. ArgoCD detects Git change → deploys via platform-owned Helm chart
EOF
fi

# Create app-env.yaml (platform contract for hello-api dev environment)
cat > workspaces/likvid/projects/hello-api/tenants/dev/app-env.yaml << 'EOF'
apiVersion: idp.meshcloud.io/v1alpha1
kind: AppEnvironment

metadata:
  name: hello-api-dev
  workspace: likvid
  project: hello-api
  tenant: dev

spec:
  # Platform-controlled namespace boundary
  target:
    namespace: app-likvid-hello-api-dev
    cluster: ske-main

  # Registry mapping (Release Controller watches this repository)
  registry:
    provider: harbor
    repository: registry.onstackit.cloud/platform-demo/hello-api
    deployPolicy:
      mode: auto

  # Runtime configuration that app teams can influence
  runtime:
    service:
      port: 8080
      protocol: http

    scaling:
      replicas: 2

    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"

  # Ingress exposure (optional)
  ingress:
    enabled: true
    host: hello-api-dev.example.com
    path: /
    tls:
      enabled: false

  # Environment variables for the application
  config:
    env:
      - name: LOG_LEVEL
        value: "info"
      - name: ENVIRONMENT
        value: "development"

  # Release channel (informational in v1)
  release:
    track: stable
EOF

# Create release.yaml (deployment release state - currently manual, future: Release Controller)
cat > workspaces/likvid/projects/hello-api/tenants/dev/release.yaml << 'EOF'
apiVersion: idp.meshcloud.io/v1alpha1
kind: AppRelease

metadata:
  workspace: likvid
  project: hello-api
  tenant: dev

spec:
  image:
    repository: registry.onstackit.cloud/platform-demo/hello-api
    tag: "v0.1.0"
    digest: "sha256:a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6"

  # Metadata about the release
  observedAt: "2025-12-30T10:00:00Z"
  observedBy: "platform-operator"
EOF

# Check if there are changes
if [ -z "$(git status --porcelain)" ]; then
  echo "Repository is already initialized and up to date"
  exit 0
fi

# Stage and commit changes
git add .
git commit -m "Initial GitOps state repository seed"

# Push to main branch
git push origin "$BRANCH" 2>/dev/null || git push -u origin "$BRANCH"

echo "Repository initialization complete"
EOT

  depends_on = [gitea_repository.state_repo]
}

# Run the initialization script
resource "null_resource" "init_repo" {
  provisioner "local-exec" {
    command = "bash ${local_file.repo_init_script.filename}"

    environment = {
      TF_VAR_gitea_token = var.gitea_token
    }
  }

  depends_on = [local_file.repo_init_script]
}
