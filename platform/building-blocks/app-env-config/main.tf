terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

locals {
  # Derive the environment name from inputs (defaults to "dev" if not specified)
  environment = var.environment != "" ? var.environment : "dev"

  # Derive app name from inputs for use in paths and commit messages
  app_name = var.app_name != "" ? var.app_name : "app"

  # Construct the GitOps state path following ADR-004 convention:
  # workspaces/<workspace-id>/projects/<project-id>/tenants/<tenant-id>/
  gitops_path = "workspaces/${var.workspace_id}/projects/${var.project_id}/tenants/${var.tenant_id}"

  # Full path to the release.yaml file in the GitOps state repository
  release_yaml_path = "${local.gitops_path}/release.yaml"

  # Determine the image reference (prefer digest over tag for immutability)
  image_reference = var.image_digest != "" ? "${var.image_repository}@${var.image_digest}" : "${var.image_repository}:${var.image_tag}"

  # Generate a commit message describing the release update
  commit_message = "Update release for ${local.app_name}/${local.environment}: ${local.image_reference}"

  # Base URL for Git operations (HTTPS clone URL)
  git_clone_url = "${var.gitea_base_url}/${split("/", var.state_repo_full_path)[0]}/${split("/", var.state_repo_full_path)[1]}.git"

  # Working directory for Git operations (cleaned up after use)
  work_dir = ".tmp/app-env-config-${var.workspace_id}-${var.project_id}-${var.tenant_id}"
}

# Render the release.yaml file content as Helm chart values.
# This file is merged with app-env.yaml by ArgoCD to provide all values to the Helm chart.
# The file contains only the deployment.image section that overrides the chart's values.yaml.
#
# IMPORTANT: release.yaml is NOT a Kubernetes CRD document; it's a YAML values file
# for the Helm chart. ArgoCD merges it with app-env.yaml as valueFiles.
locals {
  release_yaml_content = yamlencode({
    deployment = {
      image = {
        repository = var.image_repository
        tag        = var.image_tag != "" ? var.image_tag : null
        digest     = var.image_digest != "" ? var.image_digest : null
      }
    }
    # Metadata for audit trail (for operational information, not used by Helm)
    _metadata = {
      observedAt = timestamp()
      observedBy = "app-env-config-building-block"
      app        = local.app_name
      environment = local.environment
    }
  })
}

# Execute the Git operations to commit release.yaml to the GitOps state repository.
# This resource:
# 1. Clones the state repository
# 2. Creates necessary directories
# 3. Renders the release.yaml file
# 4. Commits and pushes the changes (if they are not already present)
# 5. Cleans up the working directory
#
# The implementation uses local-exec with git CLI for simplicity and auditability.
resource "null_resource" "gitops_commit" {
  triggers = {
    # Trigger updates when image reference changes
    image_reference = local.image_reference
    # Trigger updates when gitops path changes (e.g., different environment)
    gitops_path = local.gitops_path
    # Include workspace/project/tenant IDs to detect configuration changes
    workspace_id = var.workspace_id
    project_id   = var.project_id
    tenant_id    = var.tenant_id
  }

  provisioner "local-exec" {
    command = <<-BASH
      set -e  # Exit on any error
      
      # Output informational messages to stderr to avoid Terraform output pollution
      exec 2>&1
      
      echo "Starting GitOps commit for app environment..."
      echo "  Workspace: ${var.workspace_id}"
      echo "  Project: ${var.project_id}"
      echo "  Tenant: ${var.tenant_id}"
      echo "  App: ${local.app_name}"
      echo "  Environment: ${local.environment}"
      echo "  Image: ${local.image_reference}"
      
      # Create and navigate to the working directory for Git operations
      mkdir -p "${local.work_dir}"
      cd "${local.work_dir}"
      
      # Initialize Git repository if not already present, otherwise ensure we're on main branch
      if [ ! -d ".git" ]; then
        echo "Cloning GitOps state repository..."
        git clone "${local.git_clone_url}" .
      else
        echo "Repository already present, fetching latest changes..."
        git fetch origin
      fi
      
      # Configure Git credentials for the local repository
      git config user.email "platform-automation@stackit.cloud"
      git config user.name "Platform App-Env-Config Automation"
      
      # Checkout main branch and ensure we have the latest changes
      git checkout -B main origin/main || git checkout -B main
      
      # Create necessary directory structure for the release.yaml file
      mkdir -p "${local.gitops_path}"
      
      # Render the release.yaml file to the target path
      cat > "${local.release_yaml_path}" <<'YAML'
${local.release_yaml_content}
YAML
      
      echo "Rendered release.yaml to ${local.release_yaml_path}"
      
      # Check if there are any changes to commit
      if git diff --quiet && git diff --cached --quiet; then
        echo "No changes detected. Release.yaml is already up-to-date."
      else
        # Stage the release.yaml file for commit
        git add "${local.release_yaml_path}"
        
        # Commit the changes with a descriptive message
        git commit -m "${local.commit_message}" || echo "Warning: commit failed (may be empty or duplicate)"
        
        # Push the changes to the remote repository on the main branch
        # Note: This uses HTTPS authentication with username and token in the URL
        echo "Pushing changes to GitOps state repository..."
        git push "https://${var.gitea_username}:${var.gitea_token}@${replace(var.gitea_base_url, "https://", "")}/$(echo ${local.git_clone_url} | sed 's|.*/||' | sed 's|.git||').git" main
      fi
      
      echo "GitOps commit operation completed successfully."
    BASH

    interpreter = ["/bin/bash", "-c"]

    environment = {
      # Pass secrets as environment variables to avoid hardcoding them in the command
      GITEA_TOKEN    = var.gitea_token
      GITEA_USERNAME = var.gitea_username
    }
  }

  # Clean up the working directory after successful execution
  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${local.work_dir}"
    on_failure = continue  # Continue cleanup even if the directory doesn't exist
  }
}
