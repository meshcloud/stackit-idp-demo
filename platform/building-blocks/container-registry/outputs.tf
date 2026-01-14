output "registry_base" {
  value       = var.registry_base
  description = "Base URL of the container registry"
}

output "harbor_project" {
  value       = var.harbor_project
  description = "Harbor project name where images are stored"
}

output "image_repository" {
  value       = local.image_repository
  description = "Full container image repository path (without tag or digest)"
}

output "image_example_tag" {
  value       = local.image_example_tag
  description = "Example image reference with tag (copy-paste ready for docker tag/push)"
}

output "image_example_digest" {
  value       = local.image_example_digest
  description = "Example image reference with digest (immutable reference for production)"
}
