variable "gitea_username" {
  type        = string
  description = "Gitea/Forgejo username (STACKIT Git user)"
}

variable "gitea_organization" {
  type        = string
  description = "Gitea/Forgejo organization name (optional, uses username if not set)"
  default     = ""
}

variable "repository_name" {
  type        = string
  description = "Name of the repository to create"
}

variable "repository_description" {
  type        = string
  description = "Description of the repository"
  default     = ""
}

variable "repository_private" {
  type        = bool
  description = "Whether the repository should be private"
  default     = true
}

variable "repository_auto_init" {
  type        = bool
  description = "Auto-initialize the repository with README"
  default     = true
}

variable "default_branch" {
  type        = string
  description = "Default branch name"
  default     = "main"
}

variable "deploy_key_public" {
  type        = string
  description = "SSH public key for deploy access (optional)"
  default     = ""
}

variable "deploy_key_readonly" {
  type        = bool
  description = "Whether the deploy key should be read-only"
  default     = false
}

variable "gitea_base_url" {
  type        = string
  description = "STACKIT Git base URL"
  default     = "https://git-service.git.onstackit.cloud"
}

variable "gitea_token" {
  type        = string
  description = "STACKIT Git API token"
  sensitive   = true
}

variable "webhook_url" {
  type        = string
  description = "Webhook URL to configure (e.g., Argo Workflows EventSource URL)"
  default     = ""
}

variable "webhook_secret" {
  type        = string
  description = "Secret for webhook authentication"
  sensitive   = true
  default     = ""
}

variable "webhook_events" {
  type        = list(string)
  description = "Events that trigger the webhook"
  default     = ["push", "create"]
}

variable "use_template" {
  type        = bool
  description = "Create repository from template instead of empty repo"
  default     = false
}

variable "template_owner" {
  type        = string
  description = "Owner/organization of the template repository"
  default     = "stackit"
}

variable "template_name" {
  type        = string
  description = "Name of the template repository to use"
  default     = "app-template-python"
}

variable "template_variables" {
  type        = map(string)
  description = "Variables to substitute in template files (e.g., REPO_NAME, NAMESPACE)"
  default     = {}
}
