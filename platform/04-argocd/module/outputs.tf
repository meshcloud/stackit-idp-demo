output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "platform_terraform_token" {
  value     = try(data.kubernetes_secret.platform_terraform_token.data["token"], "")
  sensitive = true
  description = "Token for Terraform to manage ArgoCD resources and namespaces"
}

output "platform_terraform_ca" {
  value     = try(data.kubernetes_secret.platform_terraform_token.data["ca.crt"], "")
  sensitive = true
}
