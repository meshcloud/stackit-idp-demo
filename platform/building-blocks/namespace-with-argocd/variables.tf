variable "namespace_name" {
  type        = string
  description = "Name of the namespace to create"
}

variable "kubeconfig_path" {
  type        = string
  description = "Path to kubeconfig file"
  default     = "~/.kube/config"
}

variable "tenant_name" {
  type        = string
  description = "meshStack tenant identifier"
  default     = ""
}

variable "project_name" {
  type        = string
  description = "meshStack project identifier"
  default     = ""
}

variable "labels" {
  type        = map(string)
  description = "Additional labels for the namespace"
  default     = {}
}

variable "harbor_url" {
  type        = string
  description = "Harbor registry URL"
  default     = "registry.onstackit.cloud"
}

variable "harbor_robot_username" {
  type        = string
  description = "Harbor robot account username"
  default     = ""
  sensitive   = true
}

variable "harbor_robot_token" {
  type        = string
  description = "Harbor robot account token"
  default     = ""
  sensitive   = true
}

variable "git_repo_url" {
  type        = string
  description = "Git repository URL for ArgoCD and Argo Workflows"
  default     = ""
}

variable "git_target_revision" {
  type        = string
  description = "Git branch/tag/commit to track"
  default     = "main"
}

variable "git_manifests_path" {
  type        = string
  description = "Path to manifests in the repo"
  default     = "manifests/overlays/dev"
}

variable "argocd_namespace" {
  type        = string
  description = "Namespace where ArgoCD is installed"
  default     = "argocd"
}

variable "argocd_auto_sync" {
  type        = bool
  description = "Enable ArgoCD auto-sync"
  default     = true
}

variable "enable_argo_workflows" {
  type        = bool
  description = "Enable Argo Workflows resources for CI/CD"
  default     = false
}

variable "argo_workflows_namespace" {
  type        = string
  description = "Namespace where Argo Workflows is installed"
  default     = "argo-workflows"
}

variable "image_name" {
  type        = string
  description = "Full image name for builds (e.g., harbor.example.com/project/app)"
  default     = ""
}

variable "git_ssh_secret_name" {
  type        = string
  description = "Name of the secret containing SSH private key for git"
  default     = "git-ssh-key"
}

variable "git_ssh_private_key" {
  type        = string
  description = "SSH private key for git access (required for private repos)"
  default     = ""
  sensitive   = true
}

variable "git_ssh_known_hosts" {
  type        = string
  description = "SSH known hosts for git server"
  default     = ""
}

variable "gitea_username" {
  type        = string
  description = "Gitea username for HTTPS authentication"
  default     = ""
  sensitive   = true
}

variable "gitea_token" {
  type        = string
  description = "Gitea API token for HTTPS authentication"
  default     = ""
  sensitive   = true
}

variable "expose_app_externally" {
  type        = bool
  description = "Expose the application externally via LoadBalancer"
  default     = false
}

variable "external_port" {
  type        = number
  description = "External port for LoadBalancer service (must be unique across cluster)"
  default     = 8080
}

variable "app_selector_labels" {
  type        = map(string)
  description = "Labels to select the application pods"
  default     = {}
}

variable "app_target_port" {
  type        = number
  description = "Target port on the application pods"
  default     = 8000
}
