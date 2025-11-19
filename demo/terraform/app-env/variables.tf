# ============================================================================
# Cluster Access Variables (from bootstrap/k8s-admin module)
# ============================================================================
# These inputs enable app-env to be completely independent
# No reference to bootstrap internals - only simple input variables

variable "kube_host" {
  description = "Kubernetes API endpoint (from k8s-admin module output app_env_kube_host)"
  type        = string
  sensitive   = true
}

variable "kube_ca_certificate" {
  description = "Cluster CA certificate base64-encoded (from k8s-admin module output app_env_kube_ca_certificate)"
  type        = string
  sensitive   = true
}

variable "kube_token" {
  description = "Service account token for provisioning (from k8s-admin module output app_env_kube_token)"
  type        = string
  sensitive   = true
}

# ============================================================================
# Namespace Configuration
# ============================================================================

variable "namespace_name" {
  description = "Kubernetes namespace for application"
  type        = string
  default     = "demo-app"
}

# ============================================================================
# Resource Quota Configuration
# ============================================================================

variable "resource_quota_cpu" {
  description = "CPU request quota"
  type        = string
  default     = "4"
}

variable "resource_quota_memory" {
  description = "Memory request quota"
  type        = string
  default     = "8Gi"
}

variable "resource_quota_cpu_limit" {
  description = "CPU limit quota"
  type        = string
  default     = "8"
}

variable "resource_quota_memory_limit" {
  description = "Memory limit quota"
  type        = string
  default     = "16Gi"
}

variable "resource_quota_pods" {
  description = "Maximum number of pods"
  type        = string
  default     = "20"
}

# ============================================================================
# Container Limit Configuration
# ============================================================================

variable "container_limit_cpu" {
  description = "Maximum CPU per container"
  type        = string
  default     = "2"
}

variable "container_limit_memory" {
  description = "Maximum memory per container"
  type        = string
  default     = "4Gi"
}

variable "container_request_cpu" {
  description = "Minimum CPU per container"
  type        = string
  default     = "100m"
}

variable "container_request_memory" {
  description = "Minimum memory per container"
  type        = string
  default     = "128Mi"
}

