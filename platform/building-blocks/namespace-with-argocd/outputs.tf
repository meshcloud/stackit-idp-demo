output "namespace_name" {
  value = data.kubernetes_namespace.app.metadata[0].name
}

output "namespace_labels" {
  value = data.kubernetes_namespace.app.metadata[0].labels
}

output "argocd_application_name" {
  value = var.git_repo_url != "" ? var.namespace_name : ""
}

output "harbor_pull_secret_name" {
  value     = var.harbor_robot_username != "" && var.harbor_robot_token != "" ? "harbor-pull-secret" : ""
  sensitive = true
}

output "argo_workflows_webhook_url" {
  value       = var.enable_argo_workflows ? "http://${try(kubernetes_service.eventsource_external[0].status[0].load_balancer[0].ingress[0].ip, "pending")}:12000/${var.namespace_name}" : ""
  description = "Full external webhook URL for Argo Workflows EventSource (configure in STACKIT Git)"
}

output "argo_workflows_webhook_ip" {
  value       = var.enable_argo_workflows ? try(kubernetes_service.eventsource_external[0].status[0].load_balancer[0].ingress[0].ip, "pending") : ""
  description = "External IP for Argo Workflows EventSource webhook"
}

output "external_service_ip" {
  value       = var.expose_app_externally ? try(kubernetes_service.app_external[0].status[0].load_balancer[0].ingress[0].ip, "pending") : ""
  description = "External IP address for the LoadBalancer service"
}

output "external_service_url" {
  value       = var.expose_app_externally ? "http://${try(kubernetes_service.app_external[0].status[0].load_balancer[0].ingress[0].ip, "pending")}:${var.external_port}" : ""
  description = "Full URL to access the application externally"
}
