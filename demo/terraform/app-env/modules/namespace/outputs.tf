output "name" {
  value = kubernetes_namespace.ns.metadata[0].name
}

output "image_pull_secret_name" {
  value = length(kubernetes_secret.registry_creds) > 0 ? kubernetes_secret.registry_creds[0].metadata[0].name : ""
}
