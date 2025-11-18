variable "kubeconfig_path" {
  description = "Path to kubeconfig file for cluster access"
  type        = string
}

variable "argocd_version" {
  description = "Argo CD Helm chart version to deploy"
  type        = string
  default     = "7.3.3"  # Latest stable Argo CD Helm chart
}
