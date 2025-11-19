output "namespace_name" {
  description = "Name of the created application namespace"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "namespace_id" {
  description = "Unique identifier of the application namespace"
  value       = kubernetes_namespace.app.metadata[0].uid
}
