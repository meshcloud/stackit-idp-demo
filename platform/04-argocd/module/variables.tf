variable "kube_host" {
  type      = string
  sensitive = true
}

variable "cluster_ca_certificate" {
  type      = string
  sensitive = true
}

variable "bootstrap_client_certificate" {
  type      = string
  sensitive = true
}

variable "bootstrap_client_key" {
  type      = string
  sensitive = true
}

variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "argocd_version" {
  type    = string
  default = "7.7.5"
}

variable "admin_password_bcrypt" {
  type      = string
  sensitive = true
  description = "Bcrypt-hashed ArgoCD admin password"
}
