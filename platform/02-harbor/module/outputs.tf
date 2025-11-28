output "registry_url" {
  value = module.harbor.registry_url
}

output "platform_project_name" {
  value = var.platform_project_name
}

output "robot_username" {
  value     = module.harbor.robot_username
  sensitive = true
}

output "robot_token" {
  value     = module.harbor.robot_token
  sensitive = true
}
