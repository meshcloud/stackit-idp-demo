# Outputs for Phase A (Provision Layer)

output "cluster_name" {
  value = module.ske.cluster_name
}

output "cluster_id" {
  value = module.ske.cluster_id
}

# Kubernetes access credentials for Configuration Layer
output "kube_host" {
  description = "Kubernetes API endpoint"
  value       = module.ske.kube_host
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = module.ske.cluster_ca_certificate
  sensitive   = true
}

output "bootstrap_client_certificate" {
  description = "Client certificate for bootstrap admin access (base64-encoded)"
  value       = module.ske.bootstrap_client_certificate
  sensitive   = true
}

output "bootstrap_client_key" {
  description = "Client key for bootstrap admin access (base64-encoded)"
  value       = module.ske.bootstrap_client_key
  sensitive   = true
}

# Harbor outputs
output "registry_url" {
  value = module.harbor.registry_url
}

output "harbor_robot_username" {
  value     = module.harbor.robot_username
  sensitive = true
}

output "harbor_robot_token" {
  value     = module.harbor.robot_token
  sensitive = true
}
