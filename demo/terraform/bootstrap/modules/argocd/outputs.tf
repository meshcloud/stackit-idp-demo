output "argocd_namespace" {
  description = "Namespace where Argo CD is deployed"
  value       = "argocd"
}

output "argocd_server_service" {
  description = "Argo CD server service name (LoadBalancer)"
  value       = "argocd-server"
}

output "argocd_installed" {
  description = "Boolean indicating Argo CD installation status"
  value       = true
  depends_on  = [null_resource.argocd_verify]
}
