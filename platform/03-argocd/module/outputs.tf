output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_admin_password" {
  value       = random_password.argocd_admin.result
  sensitive   = true
  description = "ArgoCD admin password (plaintext)"
}

output "argocd_admin_password_bcrypt" {
  value       = bcrypt_hash.argocd_admin.id
  sensitive   = true
  description = "ArgoCD admin password (plaintext)"
}

output "platform_terraform_token" {
  value       = try(data.kubernetes_secret.platform_terraform_token.data["token"], "")
  sensitive   = true
  description = "Token for Terraform to manage ArgoCD resources and namespaces"
}

output "platform_terraform_ca" {
  value     = try(data.kubernetes_secret.platform_terraform_token.data["ca.crt"], "")
  sensitive = true
}
