variable "namespace_name" {
  type        = string
  description = "Name of the namespace to create"
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

variable "resource_quota_cpu" {
  type        = string
  description = "CPU resource quota"
  default     = "4"
}

variable "resource_quota_memory" {
  type        = string
  description = "Memory resource quota"
  default     = "8Gi"
}

variable "resource_quota_cpu_limit" {
  type        = string
  description = "CPU limit quota"
  default     = "8"
}

variable "resource_quota_memory_limit" {
  type        = string
  description = "Memory limit quota"
  default     = "16Gi"
}

variable "resource_quota_pods" {
  type        = string
  description = "Maximum number of pods"
  default     = "20"
}

variable "container_request_cpu" {
  type        = string
  description = "Default CPU request for containers"
  default     = "100m"
}

variable "container_request_memory" {
  type        = string
  description = "Default memory request for containers"
  default     = "128Mi"
}

variable "container_limit_cpu" {
  type        = string
  description = "Default CPU limit for containers"
  default     = "500m"
}

variable "container_limit_memory" {
  type        = string
  description = "Default memory limit for containers"
  default     = "512Mi"
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

variable "github_repo_url" {
  type        = string
  description = "GitHub repository URL for ArgoCD"
  default     = ""
}

variable "github_target_revision" {
  type        = string
  description = "Git branch/tag/commit to track"
  default     = "main"
}

variable "github_manifests_path" {
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

variable "git_repo_url" {
  type        = string
  description = "Git repository URL for Argo Workflows (e.g., STACKIT Git)"
  default     = ""
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
