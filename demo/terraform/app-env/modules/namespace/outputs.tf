output "namespace_name" {
  description = "Created Kubernetes namespace name"
  value       = kubernetes_namespace.ns.metadata[0].name
}

output "image_pull_secret_name" {
  description = "Name of the image pull secret (if created)"
  value       = length(kubernetes_secret.registry_creds) > 0 ? kubernetes_secret.registry_creds[0].metadata[0].name : ""
}
