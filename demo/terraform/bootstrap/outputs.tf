output "kubeconfig_path" {
  value = var.kubeconfig_path
}

# bootstrap/outputs.tf
output "registry_url" { value = module.harbor.registry_url }
output "harbor_robot_username" { value = module.harbor.robot_username }
output "harbor_robot_token" {
  value     = module.harbor.robot_token
  sensitive = true
}

