# meshStack domain identifiers (required, passed by meshStack during Building Block execution)

variable "workspace_id" {
  type        = string
  description = "meshStack workspace identifier (technical ID, not display name)"
  validation {
    condition     = length(var.workspace_id) > 0
    error_message = "workspace_id must not be empty."
  }
}

variable "project_id" {
  type        = string
  description = "meshStack project identifier (technical ID, not display name)"
  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "tenant_id" {
  type        = string
  description = "meshStack tenant identifier (technical ID, not display name)"
  validation {
    condition     = length(var.tenant_id) > 0
    error_message = "tenant_id must not be empty."
  }
}

# Application configuration

variable "app_name" {
  type        = string
  description = "Application name (used in metadata and paths)"
  default     = ""
}

variable "environment" {
  type        = string
  description = "Application environment name (e.g., dev, staging, prod). Default: dev"
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment) || var.environment == ""
    error_message = "environment must be one of: dev, staging, prod."
  }
}

# Container image configuration

variable "image_repository" {
  type        = string
  description = "Container image repository (e.g., harbor.example.tld/team-a/app1/dev)"
  validation {
    condition     = length(var.image_repository) > 0
    error_message = "image_repository must not be empty."
  }
}

variable "image_tag" {
  type        = string
  description = "Container image tag (optional, use digest for immutability)"
  default     = ""
  sensitive   = false
}

variable "image_digest" {
  type        = string
  description = "Container image digest (SHA256, preferred over tag for immutability). Format: sha256:abc123..."
  default     = ""
  sensitive   = false
}

# Gitea configuration for GitOps state repository

variable "gitea_base_url" {
  type        = string
  description = "Gitea instance base URL (e.g., https://git-service.git.onstackit.cloud)"
  default     = "https://git-service.git.onstackit.cloud"
  validation {
    condition     = can(regex("^https://", var.gitea_base_url))
    error_message = "gitea_base_url must be an HTTPS URL."
  }
}

variable "state_repo_full_path" {
  type        = string
  description = "Full path to the GitOps state repository (e.g., likvid/stackit-idp-state)"
  default     = "likvid/stackit-idp-state"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$", var.state_repo_full_path))
    error_message = "state_repo_full_path must be in format 'organization/repository'."
  }
}

variable "gitea_username" {
  type        = string
  description = "Gitea username for authentication (secret, used only during Building Block execution)"
  sensitive   = true
  validation {
    condition     = length(var.gitea_username) > 0
    error_message = "gitea_username must not be empty."
  }
}

variable "gitea_token" {
  type        = string
  description = "Gitea personal access token for authentication (secret, used only during Building Block execution)"
  sensitive   = true
  validation {
    condition     = length(var.gitea_token) > 0
    error_message = "gitea_token must not be empty."
  }
}
