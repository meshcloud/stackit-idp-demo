variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "argocd_version" {
  type    = string
  default = "7.7.5"
}

variable "harbor_url" {
  type        = string
  description = "Harbor registry URL"
  default     = "registry.onstackit.cloud"
}

variable "harbor_robot_username" {
  type        = string
  description = "Harbor robot account username"
  sensitive   = true
}

variable "harbor_robot_token" {
  type        = string
  description = "Harbor robot account token"
  sensitive   = true
}
