# Platform Documentation for the app-env-config Building Block

This directory contains the **app-env-config** Building Block, a platform automation component responsible for updating the GitOps state repository with container image release references.

## Overview

The **app-env-config** Building Block implements the controlled release update mechanism described in [ADR-004](../../docs/adr/ADR-004_decouple-container-builds-from-argocd.md).

It provides a safe, auditable interface for promoting container images from the Harbor registry into application environments by updating `release.yaml` files in the GitOps state repository. This is the only supported mechanism for releasing new versions in the v1 platform architecture.

## Key Responsibilities

- **Idempotent Git operations**: Clones the GitOps state repository, creates necessary directory structure, renders `release.yaml`, and commits changes to the main branch.
- **Helm values file generation**: Generates `release.yaml` as a Helm values file (not a Kubernetes CRD) that will be merged with `app-env.yaml` by ArgoCD.
- **No cluster coupling**: Does not communicate with Kubernetes or ArgoCD; changes are made purely via Git.
- **Audit trail**: All releases are committed to Git with clear commit messages and metadata.
- **Secret handling**: Gitea credentials (username + token) are treated as secrets and passed securely during execution only.

## Implementation Details

- **Language**: Terraform (HCL)
- **Providers**: `null` resource + local-exec for Git CLI operations
- **Working directory**: Temporary `.tmp/` subdirectory, cleaned up after execution
- **Authentication**: HTTPS with username + personal access token (no SSH keys on disk)
- **Idempotency**: Detects when `release.yaml` is already up-to-date; no-op commits are avoided

## Input Variables

All variables are defined in [`variables.tf`](./variables.tf).

### Required (from meshStack context)

| Variable | Type | Description |
| --- | --- | --- |
| `workspace_id` | string | meshStack workspace technical ID |
| `project_id` | string | meshStack project technical ID |
| `tenant_id` | string | meshStack tenant technical ID |

### Required (image configuration)

| Variable | Type | Description |
| --- | --- | --- |
| `image_repository` | string | Container image repository URL (e.g., `harbor.example.tld/team-a/app1/dev`) |
| Either `image_tag` or `image_digest` | string | Image reference (tag preferred for simplicity, digest preferred for immutability) |

### Required (secrets)

| Variable | Type | Description |
| --- | --- | --- |
| `gitea_username` | string (secret) | Gitea username for HTTPS authentication |
| `gitea_token` | string (secret) | Gitea personal access token for HTTPS authentication |

### Optional

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `app_name` | string | `"app"` | Application name (used in metadata and logs) |
| `environment` | string | `"dev"` | Environment name (`dev`, `staging`, `prod`) |
| `gitea_base_url` | string | `https://git-service.git.onstackit.cloud` | Gitea instance URL |
| `state_repo_full_path` | string | `likvid/stackit-idp-state` | GitOps state repository path (`org/repo`) |

## Output Values

All outputs are defined in [`outputs.tf`](./outputs.tf).

| Output | Description |
| --- | --- |
| `gitops_path` | Directory path in the repository (`workspaces/<id>/projects/<id>/tenants/<id>`) |
| `release_yaml_path` | Full path to the committed `release.yaml` file |
| `image_reference` | The image reference that was committed (digest-preferred format) |
| `commit_message` | The Git commit message used |
| `state_repo_url` | HTTPS URL of the GitOps state repository |
| `deployment_flow` | Human-readable summary of the next steps |

## How It Works

### Step-by-Step Execution

1. **Clone the GitOps state repository** from Gitea over HTTPS using provided credentials
2. **Create directory structure** following ADR-004 convention: `workspaces/<workspace-id>/projects/<project-id>/tenants/<tenant-id>/`
3. **Render `release.yaml`** according to the ADR-004 schema with the provided image reference
4. **Check for changes** using `git diff` to determine if a commit is necessary (idempotency)
5. **Commit to main** with a descriptive message if changes were detected
6. **Push to remote** using HTTPS authentication
7. **Clean up** the temporary working directory

### Idempotency Guarantee

The Building Block uses Git change detection to avoid duplicate commits:

```bash
if git diff --quiet && git diff --cached --quiet; then
  echo "No changes detected. Release.yaml is already up-to-date."
else
  git commit -m "..."
  git push ...
fi
```

This means:
- Running the Building Block twice with the same image reference is safe (no duplicate commit)
- Running with a new image reference will trigger a commit and deployment update
- Manual edits to `release.yaml` will be preserved (unless overwritten by a new Building Block execution)

### Git Operations

All Git operations use the CLI with explicit authentication:

```bash
git clone "https://${username}:${token}@${host}/org/repo.git"
git config user.email "platform-automation@stackit.cloud"
git config user.name "Platform App-Env-Config Automation"
git push "https://${username}:${token}@${host}/org/repo.git" main
```

Credentials are never hardcoded in commands; they are passed as environment variables and interpolated safely.

## Testing Locally

### Prerequisites

- Terraform installed
- Git installed
- Access to a Gitea instance with a state repository
- Valid Gitea credentials (username + personal access token)

### Manual Test

```bash
cd platform/building-blocks/app-env-config

# Initialize Terraform
terraform init

# Create a test variables file
cat > terraform.tfvars <<EOF
workspace_id       = "test-workspace"
project_id         = "test-project"
tenant_id          = "test-tenant"
app_name           = "test-app"
environment        = "dev"
image_repository   = "harbor.example.tld/test/app/dev"
image_tag          = "2025.01.10-latest"
gitea_base_url     = "https://git-service.git.onstackit.cloud"
state_repo_full_path = "likvid/stackit-idp-state"
gitea_username     = "your-username"
gitea_token        = "your-token"
EOF

# Plan the execution
terraform plan

# Apply the Building Block
terraform apply

# Check the outputs
terraform output
```

### Verify in GitOps Repository

```bash
# Clone the state repository
git clone https://git-service.git.onstackit.cloud/likvid/stackit-idp-state.git
cd stackit-idp-state

# Check the committed file
cat workspaces/test-workspace/projects/test-project/tenants/test-tenant/release.yaml

# Check the commit history
git log --oneline | head -5
```

### Cleanup

```bash
# Destroy the Terraform resources (cleans up working directory)
terraform destroy

# (Optional) Revert the Git changes if desired
git push https://...stack it-idp-state.git +HEAD~1:main
```

## Integration with the Platform

### In the Application Deployment Flow

```
Developer builds image → Harbor registry push
                          ↓
Developer runs app-env-config Building Block
  (selects environment, image reference)
                          ↓
Building Block commits release.yaml → Git
                          ↓
ArgoCD detects Git change
                          ↓
ArgoCD renders Helm chart (app-deployment)
  with app-env.yaml + release.yaml
                          ↓
ArgoCD deploys to Kubernetes
```

### Error Handling

- **Invalid credentials**: The Building Block will fail with an authentication error; check Gitea username and token.
- **Repository not found**: The Building Block will fail to clone; verify the `state_repo_full_path` and Gitea URL.
- **Permission denied**: Check that the Gitea user has push access to the state repository.
- **Merge conflicts**: Not expected in v1 (single writer). If they occur, manual Git intervention is required.

## Security Considerations

1. **Secrets**:
   - `gitea_token` and `gitea_username` are marked as `sensitive` in Terraform
   - Secrets are passed as environment variables, not hardcoded in commands
   - No credentials are persisted in the working directory after cleanup

2. **Git Operations**:
   - Uses HTTPS (not SSH) to avoid key file management on cluster nodes
   - Credentials embedded in URLs are cleaned up immediately after use

3. **Repository State**:
   - Only the designated `state_repo_full_path` repository is modified
   - The Building Block commits only to the `main` branch
   - All changes are auditable via Git history

## Future Enhancements (Out of Scope for v1)

- Support for multiple branches (e.g., feature branches for canary releases)
- Advanced release strategies (blue-green, canary) via extended `release.yaml` schema
- Automated rollback triggers
- Integration with external image scanning / compliance systems
- Multi-tenant GitOps state repository partitioning
