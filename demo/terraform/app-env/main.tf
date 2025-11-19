terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
  }
}

# Application environment Kubernetes provider
# Configured with credentials from bootstrap/platform/configure layer
provider "kubernetes" {
  host                   = var.kube_host
  cluster_ca_certificate = base64decode(var.kube_ca_certificate)
  token                  = var.kube_token
}

# Application namespace
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace_name
    labels = {
      "app.kubernetes.io/name"      = "platform-app"
      "app.kubernetes.io/component" = "application"
    }
  }
}

# ResourceQuota for namespace resource management
resource "kubernetes_resource_quota" "app" {
  metadata {
    name      = "${var.namespace_name}-quota"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.resource_quota_cpu
      "requests.memory" = var.resource_quota_memory
      "limits.cpu"      = var.resource_quota_cpu_limit
      "limits.memory"   = var.resource_quota_memory_limit
      "pods"            = var.resource_quota_pods
    }
  }
}

# LimitRange for pod resource constraints
resource "kubernetes_limit_range" "app" {
  metadata {
    name      = "${var.namespace_name}-limits"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      max = {
        cpu    = var.container_limit_cpu
        memory = var.container_limit_memory
      }

      min = {
        cpu    = var.container_request_cpu
        memory = var.container_request_memory
      }

      default_request = {
        cpu    = var.container_request_cpu
        memory = var.container_request_memory
      }

      default = {
        cpu    = var.container_limit_cpu
        memory = var.container_limit_memory
      }
    }
  }
}

# Default-deny ingress network policy
resource "kubernetes_network_policy" "deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress"]
  }
}

# Default-deny egress network policy
resource "kubernetes_network_policy" "deny_egress" {
  metadata {
    name      = "default-deny-egress"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Egress"]
  }
}
