output "registry_url" {
  description = "Base registry URL for pushing to this Harbor project"
  value       = "${replace(var.harbor_url, "https://", "")}/${var.project}"
}

output "robot_username" {
  description = "Robot account username (e.g. robot$project+ci)"
  value       = var.robot_username
}

output "robot_token" {
  description = "Robot account secret token"
  value       = var.robot_token
  sensitive   = true
}
