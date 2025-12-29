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

variable "argo_workflows_namespace" {
  type        = string
  description = "Namespace for Argo Workflows and Argo Events"
}

variable "argo_workflows_version" {
  type        = string
  description = "Helm chart version for Argo Workflows"
}

variable "argo_events_version" {
  type        = string
  description = "Helm chart version for Argo Events"
}
