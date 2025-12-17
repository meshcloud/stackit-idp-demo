# GitOps State Repository Module

This module bootstraps a GitOps state repository in STACKIT Git (Gitea/Forgejo) and seeds it with demo application manifests.

## What Gets Created

1. **Private Git Repository** in Gitea/Forgejo with auto_init enabled
2. **Directory Structure**:
   - `README.md` - Repository description
   - `tenants/demo/ai-demo/deployment.yaml` - Demo AI app manifest (namespace, deployment, service)
3. **Initial Commit** - Seeds the repository with manifests

## Prerequisites

You need Gitea/Forgejo instance running and provide:

```bash
export TF_VAR_gitea_base_url="https://git.onstackit.cloud"
export TF_VAR_gitea_token="your-api-token"
export TF_VAR_gitea_organization="platform-demo"
```

Optional:
```bash
export TF_VAR_state_repo_name="stackit-idp-state"      # default
export TF_VAR_default_branch="main"                     # default
```

## Deployment

```bash
cd platform/05-gitops-state-repo

# Set required environment variables
set -a
source ../.env
set +a

# Deploy
terragrunt init
terragrunt apply
```

## Outputs

```bash
# Get repository URLs
terragrunt output repo_https_url   # For cloning with token auth
terragrunt output repo_ssh_url     # For SSH cloning
terragrunt output repo_html_url    # Web UI URL
```

## What the Manifest Includes

The seeded `tenants/demo/ai-demo/deployment.yaml` contains:

- **Namespace**: `ai-demo` (labeled for management)
- **Deployment**: Runs `registry.onstackit.cloud/platform-demo/ai-demo:latest`
  - 1 replica by default
  - Port 8080 exposed
  - Health probes (liveness + readiness)
  - Resource requests/limits
- **Service**: ClusterIP service exposing port 80 → 8080

## Idempotency

The initialization script is idempotent:
- If the repository already exists, it won't fail
- If manifests are already present, commits only happen if changes detected
- Safe to run `terragrunt apply` multiple times

## Typical Workflow

1. Deploy this module
2. Get the repository URL: `terragrunt output repo_html_url`
3. Configure ArgoCD to sync from this repository
4. Teams can update `tenants/<team>/` with their application manifests
5. ArgoCD automatically syncs changes

## Security Notes

- Repository is **private** by default
- Token is marked as **sensitive** (won't show in logs)
- Git commits use authenticated HTTPS clone via token
- `git config user.email` is set to `terraform@stackit.cloud`

## Troubleshooting

### Repository already exists error
- Delete from Gitea UI and rerun, OR
- Manually push your changes to the existing repo

### Clone/push fails
- Check `TF_VAR_gitea_token` has correct permissions
- Verify `TF_VAR_gitea_base_url` is accessible
- Check `.tmp/repo` directory for git errors

### Manifests not created
- Check `.tmp/init-repo.sh` script output
- Verify the repository was created successfully
- Check git output in Terraform logs
