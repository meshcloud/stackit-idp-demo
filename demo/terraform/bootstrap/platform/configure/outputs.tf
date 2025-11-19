# Outputs for App-Env Layer

output "app_env_kube_host" {
  description = "Kubernetes API endpoint for app-env provisioning"
  value       = var.kube_host
  sensitive   = true
}

output "app_env_kube_ca_certificate" {
  description = "Cluster CA certificate for app-env provisioning"
  value       = var.cluster_ca_certificate
  sensitive   = true
}

output "app_env_kube_token" {
  description = "Platform-terraform ServiceAccount token for app-env provisioning"
  value       = data.kubernetes_secret.platform_terraform_token.data["token"]
  sensitive   = true
}

# Platform component information
output "platform_namespace" {
  value = kubernetes_namespace.platform_admin.metadata[0].name
}

output "platform_service_account" {
  value = kubernetes_service_account.platform_terraform.metadata[0].name
}
