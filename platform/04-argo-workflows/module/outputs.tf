output "namespace" {
  value = kubernetes_namespace.argo_workflows.metadata[0].name
}

output "workflow_service_account" {
  value = data.kubernetes_service_account.argo_workflow_sa.metadata[0].name
}
