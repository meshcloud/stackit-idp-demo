variable "kubernetes_host" {
  type        = string
  description = "Kubernetes API server endpoint"
  sensitive   = true
}

variable "kubernetes_cluster_ca_certificate" {
  type        = string
  description = "Kubernetes cluster CA certificate (base64 encoded)"
  sensitive   = true
}

variable "kubernetes_token" {
  type        = string
  description = "Kubernetes authentication token (service account or user token)"
  sensitive   = true
}

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
