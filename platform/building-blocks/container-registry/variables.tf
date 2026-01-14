variable "registry_base" {
  type        = string
  description = "Base URL of the container registry (e.g., registry.onstackit.cloud)"
  default     = "registry.onstackit.cloud"
}

variable "harbor_project" {
  type        = string
  description = "Harbor project name where images are stored (e.g., platform-demo)"
  default     = "platform-demo"
}

variable "workspace_id" {
  type        = string
  description = "meshStack workspace identifier (tenant in meshCloud terms)"
}

variable "project_id" {
  type        = string
  description = "meshStack project identifier within the workspace"
}

variable "tenant_id" {
  type        = string
  description = "Application tenant/environment identifier (e.g., dev, staging, prod)"
}

variable "app_name" {
  type        = string
  description = "Application name"
}
