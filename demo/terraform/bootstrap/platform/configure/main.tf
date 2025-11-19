# Platform Configuration Layer (Phase B)
# ============================================================================
# Configures platform components after they are provisioned
# - Reads outputs from Provision Layer
# - Configures Kubernetes provider internally
# - Creates platform-terraform ServiceAccount for app-env provisioning
#
# Outputs feed into App-Env Layer

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
  }
}

# Kubernetes provider configured with Provision Layer credentials (certificate-based auth)
provider "kubernetes" {
  host                   = var.kube_host
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  client_certificate     = base64decode(var.bootstrap_client_certificate)
  client_key             = base64decode(var.bootstrap_client_key)
}

# Platform admin namespace
resource "kubernetes_namespace" "platform_admin" {
  metadata {
    name = "platform-admin"
    labels = {
      "app.kubernetes.io/component" = "platform"
    }
  }
}

# ServiceAccount for Terraform provisioning
resource "kubernetes_service_account" "platform_terraform" {
  metadata {
    name      = "platform-terraform"
    namespace = kubernetes_namespace.platform_admin.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "terraform"
      "app.kubernetes.io/component" = "provisioner"
    }
  }

  automount_service_account_token = true
}

# Secret for token storage
resource "kubernetes_secret" "platform_terraform_token" {
  metadata {
    name      = "platform-terraform-token"
    namespace = kubernetes_namespace.platform_admin.metadata[0].name
    annotations = {
        # This annotation tells Kubernetes to attach a token for the given ServiceAccount
      "kubernetes.io/service-account.name" = kubernetes_service_account.platform_terraform.metadata[0].name
      "kubernetes.io/description" = "Token for Terraform provisioning of application environments"
    }
  }

  type = "kubernetes.io/service-account-token"
}

# ClusterRole for platform provisioning
resource "kubernetes_cluster_role" "platform_provisioner" {
  metadata {
    name = "platform-provisioner"
    labels = {
      "app.kubernetes.io/component" = "platform"
    }
  }

  # Namespace management
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }

  # ResourceQuota management
  rule {
    api_groups = [""]
    resources  = ["resourcequotas"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }

  # LimitRange management
  rule {
    api_groups = [""]
    resources  = ["limitranges"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }

  # NetworkPolicy management
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["networkpolicies"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }

  # RoleBinding management
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }

  # ClusterRoleBinding management
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["clusterrolebindings"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }

  # Secrets management
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }

  # ConfigMaps management
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create", "delete", "get", "list", "patch", "update"]
  }
}

# Bind platform provisioner role to service account
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
    namespace = kubernetes_namespace.platform_admin.metadata[0].name
  }
}

# Read the ServiceAccount secret to extract token
data "kubernetes_secret" "platform_terraform_token" {
  metadata {
    name      = kubernetes_secret.platform_terraform_token.metadata[0].name
    namespace = kubernetes_namespace.platform_admin.metadata[0].name
  }
}
