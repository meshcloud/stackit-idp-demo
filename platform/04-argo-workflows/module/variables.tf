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
