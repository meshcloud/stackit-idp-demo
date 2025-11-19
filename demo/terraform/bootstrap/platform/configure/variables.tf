# Kubernetes access credentials from Provision Layer
variable "kube_host" {
  description = "Kubernetes API endpoint (from provision layer)"
  type        = string
  sensitive   = true
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate (from provision layer)"
  type        = string
  sensitive   = true
}

variable "bootstrap_client_certificate" {
  description = "Client certificate for bootstrap admin access (base64-encoded, from provision layer)"
  type        = string
  sensitive   = true
}

variable "bootstrap_client_key" {
  description = "Client key for bootstrap admin access (base64-encoded, from provision layer)"
  type        = string
  sensitive   = true
}
