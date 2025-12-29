# ADR-004: Platform Boundaries - RBAC Foundation
# 
# This file establishes the RBAC foundation for platform/application isolation.
# App teams have no permissions to create namespaces or access Workflow CRDs.
# Enforcement happens through explicit RBAC rules (namespace creation denied by default).

# ClusterRole: limited read-only access for application teams
# Used by building blocks when creating application ServiceAccounts
resource "kubernetes_cluster_role" "app_read_only" {
  metadata {
    name = "app-read-only"
  }

  # Allow reading essential application resources
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "services", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch"]
  }
}
