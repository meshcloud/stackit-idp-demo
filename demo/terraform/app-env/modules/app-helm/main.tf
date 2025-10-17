locals {
  image_pull_secrets = var.image_pull_secret_name == "" ? [] : [
    { name = var.image_pull_secret_name }
  ]
}

resource "helm_release" "app" {
  name      = "hello-world"
  namespace = var.namespace
  chart     = var.chart_path

  values = [
    yamlencode({
      image = {
        repository = var.image_repository
        tag        = var.image_tag
      }
      service = {
        port = var.service_port
      }
      container = {
        port = var.container_port
      }
      imagePullSecrets = local.image_pull_secrets
    })
  ]
}
