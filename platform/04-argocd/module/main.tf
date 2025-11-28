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
  }
}

provider "kubernetes" {
  host                   = var.kube_host
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  client_certificate     = base64decode(var.bootstrap_client_certificate)
  client_key             = base64decode(var.bootstrap_client_key)
}

provider "helm" {
  kubernetes {
    host                   = var.kube_host
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    client_certificate     = base64decode(var.bootstrap_client_certificate)
    client_key             = base64decode(var.bootstrap_client_key)
  }
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
          argocdServerAdminPassword = var.admin_password_bcrypt
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
