output "registry_url" {
  value = "registry.stackit.cloud/${harbor_project.p.name}"
}

output "robot_username" {
  value = harbor_robot_account.ci.name
}

output "robot_token" {
  value     = harbor_robot_account.ci.secret
  sensitive = true
}
