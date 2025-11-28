output "namespace_name" {
  value = kubernetes_namespace.app.metadata[0].name
}

output "namespace_labels" {
  value = kubernetes_namespace.app.metadata[0].labels
}

output "argocd_application_name" {
  value = var.github_repo_url != "" ? var.namespace_name : ""
}

output "harbor_pull_secret_name" {
  value = var.harbor_robot_username != "" && var.harbor_robot_token != "" ? "harbor-pull-secret" : ""
}
