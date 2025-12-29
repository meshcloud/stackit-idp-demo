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

resource "kubernetes_namespace" "argo_workflows" {
  metadata {
    name = var.argo_workflows_namespace
    labels = {
      "app.kubernetes.io/name" = "argo-workflows"
    }
  }
}

resource "helm_release" "argo_workflows" {
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-workflows"
  version    = var.argo_workflows_version
  namespace  = kubernetes_namespace.argo_workflows.metadata[0].name

  values = [
    yamlencode({
      workflow = {
        serviceAccount = {
          create = true
          name   = "argo-workflow"
        }
      }
      controller = {
        workflowDefaults = {
          spec = {
            serviceAccountName = "argo-workflow"
          }
        }
      }
      server = {
        enabled = true
        extraArgs = [
          "--auth-mode=server"
        ]
        service = {
          type = "LoadBalancer"
        }
      }
    })
  ]
}

resource "helm_release" "argo_events" {
  name       = "argo-events"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-events"
  version    = var.argo_events_version
  namespace  = kubernetes_namespace.argo_workflows.metadata[0].name

  values = [
    yamlencode({
      configs = {
        jetstream = {
          versions = [
            {
              version              = "latest"
              natsImage            = "nats:latest"
              metricsExporterImage = "natsio/prometheus-nats-exporter:latest"
              configReloaderImage  = "natsio/nats-server-config-reloader:latest"
              startCommand         = "/nats-server"
            }
          ]
        }
      }
    })
  ]

  depends_on = [helm_release.argo_workflows]
}

data "kubernetes_service_account" "argo_workflow_sa" {
  metadata {
    name      = "argo-workflow"
    namespace = kubernetes_namespace.argo_workflows.metadata[0].name
  }

  depends_on = [helm_release.argo_workflows]
}

resource "kubernetes_role" "argo_workflow_role" {
  metadata {
    name      = "argo-workflow-role"
    namespace = kubernetes_namespace.argo_workflows.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "watch", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get"]
  }

  rule {
    api_groups = ["argoproj.io"]
    resources  = ["workflows", "workflowtemplates", "cronworkflows", "clusterworkflowtemplates"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "argo_workflow_binding" {
  metadata {
    name      = "argo-workflow-binding"
    namespace = kubernetes_namespace.argo_workflows.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.argo_workflow_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = data.kubernetes_service_account.argo_workflow_sa.metadata[0].name
    namespace = kubernetes_namespace.argo_workflows.metadata[0].name
  }
}
