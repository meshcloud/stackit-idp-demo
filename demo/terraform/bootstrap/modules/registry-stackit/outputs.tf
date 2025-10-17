output "registry_url" {
  value = "${local.registry_base}/${var.project_id}/${var.repo_name}"
}
