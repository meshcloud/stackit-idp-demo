# STACKIT Git Repository Building Block

Terraform building block for creating and managing Git repositories on STACKIT Git (Forgejo/Gitea).

## Features

- Creates Git repositories in STACKIT Git (user or organization)
- **Creates repositories from templates** with variable substitution
- Sets up webhooks for CI/CD integration (e.g., Argo Workflows)
- Supports both public and private repositories
- Auto-generates clone URLs based on configuration

## Prerequisites

### STACKIT Git API Token

You need a Personal Access Token from STACKIT Git:

1. Log in to STACKIT Git: https://git-service.git.onstackit.cloud
2. Go to **Settings** → **Applications** → **Manage Access Tokens**
3. Click **Generate New Token**
4. Give it a name (e.g., `terraform-automation`)
5. Select scopes:
   - `write:repository` - Required for creating/managing repos
   - `write:organization` - Required if using organizations
   - `read:user` - Required for user info
6. Copy the token immediately (shown only once)

### Provider Configuration

Configure the Gitea provider in your Terraform code or via environment variables:

**Option 1: Environment Variables (Recommended)**
```bash
export GITEA_BASE_URL="https://git-service.git.onstackit.cloud"
export GITEA_TOKEN="your-access-token-here"
```

**Option 2: Provider Block**
```hcl
provider "gitea" {
  base_url = "https://git-service.git.onstackit.cloud"
  token    = var.gitea_token
}
```

## Usage

### Basic Repository from Template

```hcl
module "my_app_repo" {
  source = "./building-blocks/stackit-git-repo"

  gitea_base_url      = "https://git-service.git.onstackit.cloud"
  gitea_token         = var.gitea_token
  gitea_username      = "myusername"
  gitea_organization  = "my-org"
  repository_name     = "my-app"
  repository_description = "My application repository"
  repository_private  = true
  
  use_template        = true
  template_owner      = "likvid"
  template_name       = "app-template-python"
  template_repo_name  = "my-app"
  template_namespace  = "my-app"
}
```

### Repository with Argo Workflows Webhook

```hcl
module "my_app_repo" {
  source = "./building-blocks/stackit-git-repo"

  gitea_base_url      = "https://git-service.git.onstackit.cloud"
  gitea_token         = var.gitea_token
  gitea_username      = "myusername"
  gitea_organization  = "my-org"
  repository_name     = "my-app"
  
  webhook_url         = "http://188.34.81.71:12000/my-app"
  webhook_secret      = "random-secret-string"
  webhook_events      = ["push"]
  
  use_template        = true
  template_owner      = "likvid"
  template_name       = "app-template-python"
  template_repo_name  = "my-app"
  template_namespace  = "my-app"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `gitea_base_url` | STACKIT Git base URL | string | `https://git-service.git.onstackit.cloud` | no |
| `gitea_token` | STACKIT Git API token | string | - | yes |
| `gitea_username` | Gitea/Forgejo username | string | - | yes |
| `gitea_organization` | Gitea/Forgejo organization name | string | `""` | no |
| `repository_name` | Name of the repository | string | - | yes |
| `repository_description` | Repository description | string | `""` | no |
| `repository_private` | Private repository | bool | `true` | no |
| `repository_auto_init` | Auto-initialize with README | bool | `true` | no |
| `default_branch` | Default branch name | string | `"main"` | no |
| `webhook_url` | Webhook URL for events | string | `""` | no |
| `webhook_secret` | Webhook authentication secret | string | `""` | no |
| `webhook_events` | Webhook trigger events | list(string) | `["push", "create"]` | no |
| `use_template` | Create from template repository | bool | `false` | no |
| `template_owner` | Template repository owner | string | `"stackit"` | no |
| `template_name` | Template repository name | string | `"app-template-python"` | no |
| `template_repo_name` | REPO_NAME variable for template substitution | string | `""` | no |
| `template_namespace` | NAMESPACE variable for template substitution | string | `""` | no |

**Note:** `CLONE_URL` is automatically generated from `gitea_base_url`, `gitea_organization` (or `gitea_username`), and `repository_name`.

## Outputs

| Name | Description |
|------|-------------|
| `repository_id` | Repository ID |
| `repository_name` | Repository name |
| `repository_html_url` | Web URL |
| `repository_ssh_url` | SSH clone URL |
| `repository_clone_url` | HTTPS clone URL |
| `summary` | Summary with next steps |

## Template Repositories

Template repositories allow you to create new repositories with pre-configured structure and code. When `use_template = true`:

1. The module uses Gitea's template API to generate a new repository from the template
2. Files listed in `.gitea/template` in the template repo are processed for variable substitution
3. Variables like `REPO_NAME`, `NAMESPACE`, `CLONE_URL` are replaced with actual values
4. The new repository is created with all content from the template

### Available Template Variables

- `REPO_NAME`: From `template_repo_name` variable
- `NAMESPACE`: From `template_namespace` variable
- `CLONE_URL`: Auto-generated from `gitea_base_url`, owner, and `repository_name`

### Creating a Template Repository

1. Create a repository with your desired structure
2. Add a `.gitea/template` file listing files for variable substitution:
   ```
   manifests/base/deployment.yaml
   manifests/base/kustomization.yaml
   README.md
   ```
3. Use template variables in those files: `REPO_NAME`, `NAMESPACE`, `CLONE_URL`
4. Mark the repository as a template in Gitea settings

## Integration with Argo Workflows

To integrate with Argo Workflows EventSource:

1. Deploy the namespace with Argo Workflows enabled
2. Get the external webhook URL from the namespace building block output
3. Create the repository with webhook pointing to that URL
4. The webhook will trigger builds on push events

Example:
```hcl
module "namespace" {
  source = "./building-blocks/namespace-with-argocd"
  
  namespace_name         = "my-app"
  app_name               = "my-app"
  gitea_username         = "myuser"
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
  webhook_secret     = "my-webhook-secret"
  
  use_template       = true
  template_owner     = "likvid"
  template_name      = "app-template-python"
  template_repo_name = "my-app"
  template_namespace = "my-app"
}
```

## Notes

- STACKIT Git is based on Forgejo (Gitea fork)
- The Gitea Terraform provider works with Forgejo/STACKIT Git
- Base URL: `https://git-service.git.onstackit.cloud`
- Uses HTTPS for git operations
- Webhooks use Gitea format (compatible with Forgejo)
- Clone URLs are automatically generated - no need to manually specify
