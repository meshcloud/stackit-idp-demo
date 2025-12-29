terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
    bcrypt = {
      source  = "viktorradnai/bcrypt"
      version = ">= 0.1.2"
    }
  }
}

# Use explicit cluster credentials instead of kubeconfig file
# to avoid storing sensitive cluster tokens on disk
provider "kubernetes" {
  host                   = var.kubernetes_host
  cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
  token                  = var.kubernetes_token
}

provider "helm" {
  kubernetes {
    host                   = var.kubernetes_host
    cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
    token                  = var.kubernetes_token
  }
}

resource "random_password" "argocd_admin" {
  length  = 24
  special = true
}

resource "bcrypt_hash" "argocd_admin" {
  cleartext = random_password.argocd_admin.result
  cost      = 10
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/name" = "argocd"
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      configs = {
        secret = {
          argocdServerAdminPassword = bcrypt_hash.argocd_admin.id
        }
      }
      server = {
        service = {
          type = "LoadBalancer"
        }
        extraArgs = [
          "--insecure"
        ]
      }
    })
  ]
}

resource "kubernetes_secret" "harbor_registry_creds" {
  metadata {
    name      = "harbor-registry-creds"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  type = "Opaque"

  data = {
    creds = "${var.harbor_robot_username}:${var.harbor_robot_token}"
  }
}

resource "helm_release" "argocd_image_updater" {
  name       = "argocd-image-updater"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  version    = "0.11.0"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      config = {
        registries = [
          {
            name        = "harbor"
            api_url     = "https://${var.harbor_url}"
            prefix      = var.harbor_url
            credentials = "secret:argocd/harbor-registry-creds#creds"
            insecure    = false
          }
        ]
      }
    })
  ]

  depends_on = [helm_release.argocd, kubernetes_secret.harbor_registry_creds]
}

resource "kubernetes_service_account" "platform_terraform" {
  metadata {
    name      = "platform-terraform"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  automount_service_account_token = true
}

resource "kubernetes_secret" "platform_terraform_token" {
  metadata {
    name      = "platform-terraform-token"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.platform_terraform.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role" "platform_provisioner" {
  metadata {
    name = "platform-provisioner"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["resourcequotas", "limitranges", "secrets", "configmaps", "serviceaccounts"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["networkpolicies"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings", "clusterrolebindings"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }

  rule {
    api_groups = ["argoproj.io"]
    resources  = ["applications", "applicationsets", "appprojects"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }
}

resource "kubernetes_cluster_role_binding" "platform_provisioner" {
  metadata {
    name = "platform-provisioner-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.platform_provisioner.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.platform_terraform.metadata[0].name
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
}

data "kubernetes_secret" "platform_terraform_token" {
  metadata {
    name      = kubernetes_secret.platform_terraform_token.metadata[0].name
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [kubernetes_secret.platform_terraform_token]
}

resource "kubernetes_secret" "harbor_pull_secret" {
  metadata {
    name      = "harbor-pull-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.harbor_url}" = {
          username = var.harbor_robot_username
          password = var.harbor_robot_token
          auth     = base64encode("${var.harbor_robot_username}:${var.harbor_robot_token}")
        }
      }
    })
  }
}
