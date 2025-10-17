variable "kubeconfig_path" {
  type = string
}

variable "namespace" {
  type    = string
  default = "argocd"
}

variable "auto_sync" {
  type    = bool
  default = true
}
