locals {
  platform_terraform_kubeconfig = {
    apiVersion = "v1"
    kind       = "Config"
    clusters = [
      {
        name = "ske-platform"
        cluster = {
          server                   = var.kube_host
          certificate-authority-data = var.cluster_ca_certificate
        }
      }
    ]
    users = [
      {
        name = "platform-terraform"
        user = {
          token = data.kubernetes_secret.platform_terraform_token.data["token"]
        }
      }
    ]
    contexts = [
      {
        name = "platform-terraform@ske-platform"
        context = {
          cluster = "ske-platform"
          user    = "platform-terraform"
        }
      }
    ]
    "current-context" = "platform-terraform@ske-platform"
  }
}

resource "local_file" "platform_terraform_kubeconfig" {
  filename = "${path.module}/platform-terraform-kubeconfig"
  content  = yamlencode(local.platform_terraform_kubeconfig)
}
