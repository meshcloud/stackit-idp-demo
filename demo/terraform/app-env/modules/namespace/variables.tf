variable "kubeconfig_path" {
  type = string
}

variable "name" {
  type = string
}

variable "create_registry_secret" {
  description = "Create a dockerconfigjson pull secret for the namespace"
  type        = bool
  default     = false
}

variable "registry_server" {
  description = "Registry server hostname (e.g., registry.stackit.cloud)"
  type        = string
  default     = "registry.stackit.cloud"
}

variable "registry_username" {
  description = "Robot/user name for registry auth"
  type        = string
  default     = ""
}

variable "registry_password" {
  description = "Robot/user token for registry auth"
  type        = string
  default     = ""
  sensitive   = true
}
