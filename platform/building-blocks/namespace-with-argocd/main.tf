terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

locals {
  app_name     = var.app_name != "" ? var.app_name : var.namespace_name
  git_repo_url = var.git_repo_url != "" ? var.git_repo_url : "https://git-service.git.onstackit.cloud/${var.gitea_username}/${local.app_name}.git"
  image_name   = var.image_name != "" ? var.image_name : "${var.harbor_url}/registry/${local.app_name}"
  tenant_name  = var.tenant_name != "" ? var.tenant_name : local.app_name
  project_name = var.project_name != "" ? var.project_name : local.app_name
  app_selector_labels = length(var.app_selector_labels) > 0 ? var.app_selector_labels : {
    "app.kubernetes.io/name" = local.app_name
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
      "meshstack.io/tenant"          = local.tenant_name
      "meshstack.io/project"         = local.project_name
      "argocd.argoproj.io/managed"   = "true"
    },
    var.labels
  )
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

resource "kubernetes_secret" "argocd_repo_creds" {
  count = var.gitea_username != "" && var.gitea_token != "" ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-repo-creds"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    username = var.gitea_username
    password = var.gitea_token
    type     = "git"
    url      = local.git_repo_url
  }
}

resource "kubernetes_secret" "workflow_repo_creds" {
  count = var.enable_argo_workflows && var.gitea_username != "" && var.gitea_token != "" ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-repo-creds"
    namespace = data.kubernetes_namespace.app.metadata[0].name
  }

  type = "Opaque"

  data = {
    username = var.gitea_username
    password = var.gitea_token
  }
}

resource "kubernetes_manifest" "argocd_application" {
  count = local.git_repo_url != "" ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.namespace_name
      namespace = var.argocd_namespace
      labels = {
        "meshstack.io/tenant"  = local.tenant_name
        "meshstack.io/project" = local.project_name
      }
      annotations = {
        "argocd-image-updater.argoproj.io/image-list"          = "app=${local.image_name}"
        "argocd-image-updater.argoproj.io/app.update-strategy" = "newest-build"
        "argocd-image-updater.argoproj.io/write-back-method"   = "argocd"
      }
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = local.git_repo_url
        targetRevision = var.git_target_revision
        path           = var.git_manifests_path
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

resource "kubernetes_manifest" "eventbus" {
  count = var.enable_argo_workflows ? 1 : 0

  field_manager {
    force_conflicts = true
  }

  computed_fields = [
    "spec.jetstream.initContainerTemplate",
    "spec.jetstream.reloadContainerTemplate"
  ]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "EventBus"
    metadata = {
      name      = "default"
      namespace = data.kubernetes_namespace.app.metadata[0].name
    }
    spec = {
      jetstream = {
        version      = "latest"
        replicas     = 1
        encryption   = false
        streamConfig = <<-EOT
          duplicates: 300s
          maxage: 72h
          maxbytes: 1GB
          maxmsgs: 1000000
          replicas: 1
        EOT
        containerTemplate = {
          resources = {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }
        metricsContainerTemplate = {
          resources = {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
        initContainerTemplate = {
          resources = {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
        reloadContainerTemplate = {
          resources = {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_limit_range" "default_limits" {
  count = var.enable_argo_workflows ? 1 : 0

  metadata {
    name      = "default-container-limits"
    namespace = data.kubernetes_namespace.app.metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "100m"
        memory = "128Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
  }
}

resource "kubernetes_manifest" "workflow_eventsource" {
  count = var.enable_argo_workflows && local.git_repo_url != "" ? 1 : 0

  field_manager {
    force_conflicts = true
  }

  computed_fields = ["spec.template.container.name"]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "EventSource"
    metadata = {
      name      = "${var.namespace_name}-git"
      namespace = var.namespace_name
    }
    spec = {
      eventBusName = "default"
      template = {
        metadata = {
          labels = {
            "networking.gardener.cloud/to-dns" = "allowed"
          }
        }
        container = {
          resources = {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
      }
      service = {
        ports = [
          {
            port       = 12000
            targetPort = 12000
          }
        ]
      }
      webhook = {
        "${var.namespace_name}" = {
          port     = "12000"
          endpoint = "/${var.namespace_name}"
          method   = "POST"
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.eventbus]
}

resource "kubernetes_manifest" "workflow_sensor" {
  count = var.enable_argo_workflows && local.git_repo_url != "" ? 1 : 0

  field_manager {
    force_conflicts = true
  }

  computed_fields = ["spec.template.container.name"]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Sensor"
    metadata = {
      name      = "${var.namespace_name}-sensor"
      namespace = var.namespace_name
    }
    spec = {
      eventBusName = "default"
      template = {
        metadata = {
          labels = {
            "networking.gardener.cloud/to-dns" = "allowed"
          }
        }
        container = {
          resources = {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
        serviceAccountName = "argo-workflow"
      }
      dependencies = [
        {
          name            = var.namespace_name
          eventSourceName = "${var.namespace_name}-git"
          eventName       = var.namespace_name
        }
      ]
      triggers = [
        {
          template = {
            name = "trigger-build-${var.namespace_name}"
            k8s = {
              operation = "create"
              source = {
                resource = {
                  apiVersion = "argoproj.io/v1alpha1"
                  kind       = "Workflow"
                  metadata = {
                    generateName = "build-${var.namespace_name}-"
                    namespace    = var.namespace_name
                  }
                  spec = {
                    serviceAccountName = "argo-workflow"
                    workflowTemplateRef = {
                      name = "kaniko-build"
                    }
                    arguments = {
                      parameters = [
                        {
                          name  = "repo-url"
                          value = local.git_repo_url
                        },
                        {
                          name  = "revision"
                          value = "main"
                        },
                        {
                          name  = "image-name"
                          value = local.image_name
                        }
                      ]
                    }
                  }
                }
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.workflow_eventsource, kubernetes_manifest.eventbus]
}

resource "kubernetes_manifest" "kaniko_workflow_template" {
  count = var.enable_argo_workflows && local.image_name != "" ? 1 : 0

  field_manager {
    force_conflicts = true
  }

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "WorkflowTemplate"
    metadata = {
      name      = "kaniko-build"
      namespace = data.kubernetes_namespace.app.metadata[0].name
    }
    spec = {
      serviceAccountName = "argo-workflow"
      podMetadata = {
        labels = {
          "networking.gardener.cloud/to-dns"             = "allowed"
          "networking.gardener.cloud/to-public-networks" = "allowed"
        }
      }
      arguments = {
        parameters = [
          {
            name  = "repo-url"
            value = ""
          },
          {
            name  = "revision"
            value = "main"
          },
          {
            name  = "image-name"
            value = local.image_name
          },
          {
            name  = "git-sha"
            value = ""
          },
          {
            name  = "dockerfile-path"
            value = "app/Dockerfile"
          },
          {
            name  = "context-path"
            value = "app"
          }
        ]
      }
      entrypoint = "build-and-push"
      volumes = [
        {
          name = "docker-config"
          secret = {
            secretName = "harbor-pull-secret"
            items = [
              {
                key  = ".dockerconfigjson"
                path = "config.json"
              }
            ]
          }
        }
      ]
      templates = [
        {
          name = "build-and-push"
          steps = [
            [
              {
                name     = "clone"
                template = "git-clone"
              }
            ],
            [
              {
                name     = "build"
                template = "kaniko-build"
                arguments = {
                  parameters = [
                    {
                      name  = "git-sha"
                      value = "{{steps.clone.outputs.parameters.git-sha}}"
                    }
                  ]
                }
              }
            ]
          ]
        },
        {
          name = "git-clone"
          inputs = {
            artifacts = [
              {
                name = "source-code"
                path = "/workspace"
                git = {
                  repo     = "{{workflow.parameters.repo-url}}"
                  revision = "{{workflow.parameters.revision}}"
                  usernameSecret = {
                    name = "${var.namespace_name}-repo-creds"
                    key  = "username"
                  }
                  passwordSecret = {
                    name = "${var.namespace_name}-repo-creds"
                    key  = "password"
                  }
                }
              }
            ]
          }
          outputs = {
            parameters = [
              {
                name = "git-sha"
                valueFrom = {
                  path = "/tmp/git-tag"
                }
              }
            ]
          }
          container = {
            image   = "alpine/git:latest"
            command = ["sh", "-c"]
            args = [
              "cd /workspace && TAG=$(git describe --tags --exact-match 2>/dev/null || echo \"\") && if [ -n \"$TAG\" ]; then echo \"$TAG\" > /tmp/git-tag; else git rev-parse --short HEAD > /tmp/git-tag; fi && echo \"Using tag: $(cat /tmp/git-tag)\" && ls -la /workspace"
            ]
            resources = {
              requests = {
                cpu    = "100m"
                memory = "128Mi"
              }
              limits = {
                cpu    = "200m"
                memory = "256Mi"
              }
            }
          }
        },
        {
          name = "kaniko-build"
          inputs = {
            parameters = [
              {
                name = "git-sha"
              }
            ]
            artifacts = [
              {
                name = "source-code"
                path = "/workspace"
                git = {
                  repo     = "{{workflow.parameters.repo-url}}"
                  revision = "{{workflow.parameters.revision}}"
                  usernameSecret = {
                    name = "${var.namespace_name}-repo-creds"
                    key  = "username"
                  }
                  passwordSecret = {
                    name = "${var.namespace_name}-repo-creds"
                    key  = "password"
                  }
                }
              }
            ]
          }
          container = {
            image   = "gcr.io/kaniko-project/executor:latest"
            command = ["/kaniko/executor"]
            args = [
              "--dockerfile={{workflow.parameters.dockerfile-path}}",
              "--context=/workspace/{{workflow.parameters.context-path}}",
              "--destination={{workflow.parameters.image-name}}:{{inputs.parameters.git-sha}}",
              "--cache=true",
              "--cache-ttl=24h"
            ]
            volumeMounts = [
              {
                name      = "docker-config"
                mountPath = "/kaniko/.docker/"
              }
            ]
            resources = {
              requests = {
                cpu    = "500m"
                memory = "512Mi"
              }
              limits = {
                cpu    = "1000m"
                memory = "1Gi"
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_service_account.argo_workflow, kubernetes_secret.harbor_pull_secret]
}

resource "kubernetes_service_account" "argo_workflow" {
  count = var.enable_argo_workflows ? 1 : 0

  metadata {
    name      = "argo-workflow"
    namespace = data.kubernetes_namespace.app.metadata[0].name
  }
}

resource "kubernetes_role" "argo_workflow" {
  count = var.enable_argo_workflows ? 1 : 0

  metadata {
    name      = "argo-workflow-role"
    namespace = data.kubernetes_namespace.app.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "watch", "patch", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get"]
  }

  rule {
    api_groups = ["argoproj.io"]
    resources  = ["workflows", "workflowtemplates"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["argoproj.io"]
    resources  = ["workflowtaskresults"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "argo_workflow" {
  count = var.enable_argo_workflows ? 1 : 0

  metadata {
    name      = "argo-workflow-binding"
    namespace = data.kubernetes_namespace.app.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.argo_workflow[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.argo_workflow[0].metadata[0].name
    namespace = data.kubernetes_namespace.app.metadata[0].name
  }
}


resource "kubernetes_service" "app_external" {
  count = var.expose_app_externally && length(local.app_selector_labels) > 0 ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-external"
    namespace = data.kubernetes_namespace.app.metadata[0].name
    annotations = {
      "terraform-managed" = "true"
      "external-port"     = tostring(var.external_port)
    }
  }

  spec {
    type = "LoadBalancer"

    selector = local.app_selector_labels

    port {
      port        = var.external_port
      target_port = var.app_target_port
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_service" "eventsource_external" {
  count = var.enable_argo_workflows && local.git_repo_url != "" ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-git-eventsource-external"
    namespace = data.kubernetes_namespace.app.metadata[0].name
    annotations = {
      "terraform-managed" = "true"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "eventsource-name" = "${var.namespace_name}-git"
    }

    port {
      port        = 12000
      target_port = 12000
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_manifest.workflow_eventsource]
}
