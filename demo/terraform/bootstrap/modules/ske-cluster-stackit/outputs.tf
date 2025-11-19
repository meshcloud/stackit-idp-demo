output "kubeconfig_path" { 
  value = var.kubeconfig_out_path
}

output "cluster_name" { 
  value = stackit_ske_cluster.this.name
}

output "cluster_id" {
  value = stackit_ske_cluster.this.id
}

# Extract cluster endpoint and CA certificate from kubeconfig YAML
# The STACKIT provider returns kube_config as a raw YAML string
locals {
  kubeconfig_yaml = yamldecode(stackit_ske_kubeconfig.cfg.kube_config)
  cluster_info    = local.kubeconfig_yaml.clusters[0].cluster
  user_info       = local.kubeconfig_yaml.users[0].user
}

output "kube_host" {
  description = "Kubernetes API endpoint for bootstrap admin access"
  value       = local.cluster_info.server
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = local.cluster_info.certificate-authority-data
  sensitive   = true
}

output "bootstrap_client_certificate" {
  description = "Client certificate for cluster admin access"
  value       = local.user_info.client-certificate-data
  sensitive   = true
}

output "bootstrap_client_key" {
  description = "Client key for cluster admin access"
  value       = local.user_info.client-key-data
  sensitive   = true
}

# Deprecated outputs (kept for backward compatibility)
output "cluster_endpoint" { 
  value     = local.cluster_info.server
  sensitive = true
}
