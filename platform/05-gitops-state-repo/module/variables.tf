variable "gitea_base_url" {
  description = "Base URL of the Gitea/Forgejo instance"
  type        = string
  sensitive   = false
}

variable "gitea_token" {
  description = "API token for Gitea authentication"
  type        = string
  sensitive   = true
}

variable "gitea_organization" {
  description = "Gitea organization where repository will be created"
  type        = string
}

variable "state_repo_name" {
  description = "Name of the GitOps state repository"
  type        = string
  default     = "stackit-idp-state"
}

variable "default_branch" {
  description = "Default branch for the repository"
  type        = string
  default     = "main"
}
