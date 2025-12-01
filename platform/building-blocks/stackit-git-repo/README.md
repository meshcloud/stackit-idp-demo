# STACKIT Git Repository Building Block

Terraform building block for creating and managing Git repositories on STACKIT Git (Forgejo/Gitea).

## Features

- Creates Git repositories in STACKIT Git (user or organization)
- **Creates repositories from templates** with variable substitution
- Configures SSH deploy keys for repository access
- Sets up webhooks for CI/CD integration (e.g., Argo Workflows)
- Supports both public and private repositories

## Prerequisites

### STACKIT Git API Token

You need a Personal Access Token from STACKIT Git:

1. Log in to STACKIT Git: https://git.api.stackit.cloud
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
export GITEA_BASE_URL="https://git.api.stackit.cloud"
export GITEA_TOKEN="your-access-token-here"
```

**Option 2: Provider Block**
```hcl
provider "gitea" {
  base_url = "https://git.api.stackit.cloud"
  token    = var.gitea_token
}
```

## Usage

### Basic Repository

```hcl
module "my_app_repo" {
  source = "./building-blocks/stackit-git-repo"

  gitea_username      = "myusername"
  repository_name     = "my-app"
  repository_description = "My application repository"
  repository_private  = true
}
```

### Repository with Deploy Key

```hcl
module "my_app_repo" {
  source = "./building-blocks/stackit-git-repo"

  gitea_username      = "myusername"
  repository_name     = "my-app"
  
  deploy_key_public   = "ssh-rsa AAAAB3NzaC1yc2EA..."
  deploy_key_readonly = false
}
```

### Repository with Argo Workflows Webhook

```hcl
module "my_app_repo" {
  source = "./building-blocks/stackit-git-repo"

  gitea_username      = "myusername"
  repository_name     = "my-app"
  
  webhook_url         = "http://my-namespace-git-eventsource-svc.my-namespace.svc:12000/my-namespace"
  webhook_secret      = "random-secret-string"
  webhook_events      = ["push"]
}
```

### Organization Repository

```hcl
module "team_app_repo" {
  source = "./building-blocks/stackit-git-repo"

  gitea_username       = "myusername"
  gitea_organization   = "my-team"
  repository_name      = "team-app"
}
```

### Repository from Template

```hcl
module "app_from_template" {
  source = "./building-blocks/stackit-git-repo"

  gitea_username      = "myusername"
  gitea_organization  = "my-team"
  repository_name     = "my-new-app"
  
  use_template        = true
  template_owner      = "stackit"
  template_name       = "app-template-python"
  template_variables  = {
    REPO_NAME  = "my-new-app"
    NAMESPACE  = "my-namespace"
    CLONE_URL  = "https://git-service.git.onstackit.cloud/my-team/my-new-app.git"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `gitea_username` | Gitea/Forgejo username | string | - | yes |
| `gitea_organization` | Gitea/Forgejo organization name | string | `""` | no |
| `repository_name` | Name of the repository | string | - | yes |
| `repository_description` | Repository description | string | `""` | no |
| `repository_private` | Private repository | bool | `true` | no |
| `repository_auto_init` | Auto-initialize with README | bool | `true` | no |
| `default_branch` | Default branch name | string | `"main"` | no |
| `deploy_key_public` | SSH public key for deploy access | string | `""` | no |
| `deploy_key_readonly` | Read-only deploy key | bool | `false` | no |
| `webhook_url` | Webhook URL for events | string | `""` | no |
| `webhook_secret` | Webhook authentication secret | string | `""` | no |
| `webhook_events` | Webhook trigger events | list(string) | `["push", "create"]` | no |
| `use_template` | Create from template repository | bool | `false` | no |
| `template_owner` | Template repository owner | string | `"stackit"` | no |
| `template_name` | Template repository name | string | `"app-template-python"` | no |
| `template_variables` | Variables for template substitution | map(string) | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `repository_id` | Repository ID |
| `repository_name` | Repository name |
| `repository_full_name` | Full repository name (org/repo) |
| `repository_html_url` | Web URL |
| `repository_ssh_url` | SSH clone URL |
| `repository_clone_url` | HTTPS clone URL |
| `deploy_key_id` | Deploy key ID (if created) |
| `webhook_id` | Webhook ID (if created) |

## Integration with Argo Workflows

To integrate with Argo Workflows EventSource:

1. Deploy the namespace with Argo Workflows enabled
2. Get the EventSource service URL: `http://<namespace>-git-eventsource-svc.<namespace>.svc:12000/<namespace>`
3. Create the repository with webhook pointing to that URL
4. The webhook will trigger builds on push events

Example:
```hcl
module "namespace" {
  source = "./building-blocks/namespace-with-argocd"
  
  namespace_name         = "my-app"
  enable_argo_workflows = true
  git_repo_url          = "https://git.api.stackit.cloud/myuser/my-app.git"
  image_name            = "registry.onstackit.cloud/myproject/my-app"
}

module "repo" {
  source = "./building-blocks/stackit-git-repo"
  
  gitea_username    = "myuser"
  repository_name   = "my-app"
  webhook_url       = "http://my-app-git-eventsource-svc.my-app.svc:12000/my-app"
  webhook_secret    = "my-webhook-secret"
}
```

## Template Repositories

Template repositories allow you to create new repositories with pre-configured structure and code. When `use_template = true`:

1. The module uses Gitea's template API to generate a new repository from the template
2. Files listed in `.gitea/template` in the template repo are processed for variable substitution
3. Variables like `${REPO_NAME}`, `${NAMESPACE}`, `${CLONE_URL}` are replaced with actual values
4. The new repository is created with all content from the template

### Creating a Template Repository

1. Create a repository with your desired structure
2. Add a `.gitea/template` file listing files for variable substitution:
   ```
   manifests/base/deployment.yaml
   manifests/base/kustomization.yaml
   README.md
   ```
3. Use template variables in those files: `${REPO_NAME}`, `${NAMESPACE}`, etc.
4. Mark the repository as a template in Gitea settings or via API

## Notes

- STACKIT Git is based on Forgejo (Gitea fork)
- The Gitea Terraform provider works with Forgejo/STACKIT Git
- Base URL: `https://git-service.git.onstackit.cloud`
- Uses HTTPS for git operations
- Webhooks use Gitea format (compatible with Forgejo)
