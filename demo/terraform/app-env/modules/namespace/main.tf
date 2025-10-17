resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.name
  }
}

# Optional dockerconfigjson pull secret
locals {
  make_secret = var.create_registry_secret && length(var.registry_username) > 0 && length(var.registry_password) > 0

  dockerconfigjson = jsonencode({
    auths = {
      (var.registry_server) = {
        username = var.registry_username
        password = var.registry_password
        auth     = base64encode("${var.registry_username}:${var.registry_password}")
      }
    }
  })
}

resource "kubernetes_secret" "registry_creds" {
  count = local.make_secret ? 1 : 0

  metadata {
    name      = "registry-pull-secret"
    namespace = kubernetes_namespace.ns.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = base64encode(local.dockerconfigjson)
  }
}
