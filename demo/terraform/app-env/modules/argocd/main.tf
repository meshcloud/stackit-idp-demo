resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "argo_cd" {
  name       = "argo-cd"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "6.9.0"

  values = [
    yamlencode({
      configs = {
        params = { "server.insecure" = "false" }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}
