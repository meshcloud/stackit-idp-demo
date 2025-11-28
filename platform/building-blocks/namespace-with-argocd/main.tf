terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
  }
}

data "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace_name
  }
}

resource "kubernetes_labels" "app_namespace" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = var.namespace_name
  }
  labels = merge(
    {
      "app.kubernetes.io/managed-by" = "terraform"
      "meshstack.io/tenant"          = var.tenant_name
      "meshstack.io/project"         = var.project_name
      "argocd.argoproj.io/managed"   = "true"
    },
    var.labels
  )
}

resource "kubernetes_resource_quota" "app" {
  metadata {
    name      = "${var.namespace_name}-quota"
    namespace = data.kubernetes_namespace.app.metadata[0].name
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

resource "kubernetes_limit_range" "app" {
  metadata {
    name      = "${var.namespace_name}-limits"
    namespace = data.kubernetes_namespace.app.metadata[0].name
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

resource "kubernetes_network_policy" "deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = data.kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "deny_egress" {
  metadata {
    name      = "default-deny-egress"
    namespace = data.kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]
  }
}

resource "kubernetes_secret" "harbor_pull_secret" {
  count = var.harbor_robot_username != "" && var.harbor_robot_token != "" ? 1 : 0

  metadata {
    name      = "harbor-pull-secret"
    namespace = data.kubernetes_namespace.app.metadata[0].name
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

resource "kubernetes_manifest" "argocd_application" {
  count = var.github_repo_url != "" ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.namespace_name
      namespace = var.argocd_namespace
      labels = {
        "meshstack.io/tenant"  = var.tenant_name
        "meshstack.io/project" = var.project_name
      }
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.github_repo_url
        targetRevision = var.github_target_revision
        path           = var.github_manifests_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = data.kubernetes_namespace.app.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = var.argocd_auto_sync
        }
        syncOptions = [
          "CreateNamespace=false"
        ]
      }
    }
  }
}

resource "kubernetes_role" "app_deployer" {
  metadata {
    name      = "${var.namespace_name}-deployer"
    namespace = data.kubernetes_namespace.app.metadata[0].name
  }

  rule {
    api_groups = ["", "apps", "batch", "networking.k8s.io"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "app_deployer" {
  metadata {
    name      = "${var.namespace_name}-deployer"
    namespace = data.kubernetes_namespace.app.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.app_deployer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argocd-application-controller"
    namespace = var.argocd_namespace
  }
}
