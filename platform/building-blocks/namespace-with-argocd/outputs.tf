output "namespace_name" {
  value = data.kubernetes_namespace.app.metadata[0].name
}

output "namespace_labels" {
  value = data.kubernetes_namespace.app.metadata[0].labels
}

output "argocd_application_name" {
  value = var.namespace_name
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

output "summary" {
  description = "Summary with next steps and insights into created resources"
  value       = <<-EOT
# Namespace and ArgoCD Application Deployed

✅ **Your application environment is ready!**

## Kubernetes Resources

- **Namespace**: `${var.namespace_name}`
- **ArgoCD Application**: `${var.namespace_name}`
${var.harbor_robot_username != "" && var.harbor_robot_token != "" ? "- **Harbor Pull Secret**: Configured for private images" : ""}

## Application Access

${var.expose_app_externally && try(kubernetes_service.app_external[0].status[0].load_balancer[0].ingress[0].ip, "") != "" ? "- **Application URL**: [${try(kubernetes_service.app_external[0].status[0].load_balancer[0].ingress[0].ip, "pending")}:${var.external_port}](http://${try(kubernetes_service.app_external[0].status[0].load_balancer[0].ingress[0].ip, "pending")}:${var.external_port})" : ""}
${var.enable_argo_workflows && try(kubernetes_service.eventsource_external[0].status[0].load_balancer[0].ingress[0].ip, "") != "" ? "- **Webhook URL**: `${try(kubernetes_service.eventsource_external[0].status[0].load_balancer[0].ingress[0].ip, "pending")}:12000/${var.namespace_name}`" : ""}

## Deployment Pipeline

Your GitOps deployment pipeline is active:

1. **ArgoCD detects changes** and syncs automatically
2. **Kubernetes deploys** your application to namespace `${var.namespace_name}`

${var.enable_argo_workflows ? "## CI/CD Integration\n\nArgo Workflows is enabled for automated builds:\n- Webhook events from Git trigger workflow executions\n- Builds run in namespace `${var.namespace_name}`\n- Images are pushed to Harbor registry" : ""}

## ArgoCD Dashboard

Monitor your deployment in ArgoCD:
- Look for application: `${var.namespace_name}`
- Check sync status and health
EOT
}
