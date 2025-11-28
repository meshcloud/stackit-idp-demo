terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  host                   = var.kube_host
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  client_certificate     = base64decode(var.bootstrap_client_certificate)
  client_key             = base64decode(var.bootstrap_client_key)
}

module "meshplatform" {
  source = "git::https://github.com/meshcloud/terraform-kubernetes-meshplatform.git?ref=v0.1.0"
}
