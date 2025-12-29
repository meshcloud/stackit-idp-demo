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

# Create directory structure
mkdir -p tenants/demo/ai-demo

# Create README.md if it doesn't exist
if [ ! -f README.md ] || [ ! -s README.md ]; then
  cat > README.md << 'EOF'
# STACKIT IDP GitOps State Repository

This repository contains Kubernetes manifests managed by ArgoCD for the STACKIT Internal Developer Platform.

## Structure

- `tenants/` - Per-tenant application manifests
- `tenants/demo/` - Demo tenant
- `tenants/demo/ai-demo/` - Demo AI application

## GitOps Workflow

1. Push changes to this repository
2. ArgoCD detects changes
3. ArgoCD applies manifests to the cluster
EOF
fi

# Create deployment manifest
mkdir -p tenants/demo/ai-demo
cat > tenants/demo/ai-demo/deployment.yaml << 'EOF'
---
apiVersion: v1
kind: Namespace
metadata:
  name: ai-demo
  labels:
    name: ai-demo

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-demo
  namespace: ai-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ai-demo
  template:
    metadata:
      labels:
        app: ai-demo
    spec:
      containers:
      - name: ai-demo
        image: registry.onstackit.cloud/platform-demo/ai-demo:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5

---
apiVersion: v1
kind: Service
metadata:
  name: ai-demo
  namespace: ai-demo
spec:
  selector:
    app: ai-demo
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
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
