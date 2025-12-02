terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
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
  app_name         = var.app_name != "" ? var.app_name : var.namespace_name
  git_repo_url     = var.git_repo_url != "" ? var.git_repo_url : "https://git-service.git.onstackit.cloud/${var.gitea_username}/${local.app_name}.git"
  image_name       = var.image_name != "" ? var.image_name : "${var.harbor_url}/registry/${local.app_name}"
  tenant_name      = var.tenant_name != "" ? var.tenant_name : local.app_name
  project_name     = var.project_name != "" ? var.project_name : local.app_name
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

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "EventBus"
    metadata = {
      name      = "default"
      namespace = data.kubernetes_namespace.app.metadata[0].name
    }
    spec = {
      jetstream = {
        version  = "latest"
        replicas = 1
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

resource "null_resource" "eventbus_status_patch" {
  count = var.enable_argo_workflows ? 1 : 0

  triggers = {
    eventbus_id = kubernetes_manifest.eventbus[0].manifest.metadata.namespace
    replicas    = 1
  }

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"
      
      echo "Waiting for EventBus to be created..."
      kubectl wait --for=condition=Deployed eventbus/default -n ${data.kubernetes_namespace.app.metadata[0].name} --timeout=120s || true
      
      echo "Patching EventBus status with replicas and streamConfig..."
      kubectl patch eventbus default -n ${data.kubernetes_namespace.app.metadata[0].name} --subresource=status --type=merge -p '{"status":{"config":{"jetstream":{"replicas":1,"streamConfig":"duplicates: 300s\nmaxage: 72h\nmaxbytes: 1GB\nmaxmsgs: 1000000\nreplicas: 1\n"}}}}'
      
      echo "Waiting for StatefulSet to be created by EventBus controller..."
      sleep 5
      
      echo "Patching StatefulSet to add reloader container resources (Argo Events controller bug workaround)..."
      kubectl patch statefulset eventbus-default-js -n ${data.kubernetes_namespace.app.metadata[0].name} --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/1/resources", "value": {"limits": {"cpu": "100m", "memory": "128Mi"}, "requests": {"cpu": "50m", "memory": "64Mi"}}}]' || true
      
      echo "EventBus configuration completed"
    EOT
  }

  depends_on = [kubernetes_manifest.eventbus]
}

resource "null_resource" "workflow_eventsource" {
  count = var.enable_argo_workflows && local.git_repo_url != "" ? 1 : 0

  triggers = {
    namespace = var.namespace_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"
      kubectl apply --server-side --force-conflicts -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: ${var.namespace_name}-git
  namespace: ${var.namespace_name}
spec:
  eventBusName: default
  template:
    metadata:
      labels:
        networking.gardener.cloud/to-dns: allowed
    container:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    ${var.namespace_name}:
      port: "12000"
      endpoint: /${var.namespace_name}
      method: POST
EOF
    EOT
  }

  depends_on = [kubernetes_manifest.eventbus]
}

resource "null_resource" "workflow_sensor" {
  count = var.enable_argo_workflows && local.git_repo_url != "" ? 1 : 0

  triggers = {
    namespace    = var.namespace_name
    git_repo_url = local.git_repo_url
    image_name   = local.image_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply --server-side --force-conflicts -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: ${var.namespace_name}-sensor
  namespace: ${var.namespace_name}
spec:
  eventBusName: default
  template:
    metadata:
      labels:
        networking.gardener.cloud/to-dns: allowed
    container:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
    serviceAccountName: argo-workflow
  dependencies:
    - name: ${var.namespace_name}
      eventSourceName: ${var.namespace_name}-git
      eventName: ${var.namespace_name}
  triggers:
    - template:
        name: trigger-build-${var.namespace_name}
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: build-${var.namespace_name}-
                namespace: ${var.namespace_name}
              spec:
                serviceAccountName: argo-workflow
                workflowTemplateRef:
                  name: kaniko-build
                arguments:
                  parameters:
                    - name: repo-url
                      value: ${local.git_repo_url}
                    - name: revision
                      value: main
                    - name: image-name
                      value: ${local.image_name}
                    - name: image-tag
                      value: latest
EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete sensor ${self.triggers.namespace}-sensor -n ${self.triggers.namespace} --ignore-not-found=true"
  }

  depends_on = [null_resource.workflow_eventsource, kubernetes_manifest.eventbus]
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
            name  = "image-tag"
            value = "latest"
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
          container = {
            image   = "alpine/git:latest"
            command = ["sh", "-c"]
            args = [
              "echo 'Repository cloned successfully' && ls -la /workspace"
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
              "--destination={{workflow.parameters.image-name}}:{{workflow.parameters.image-tag}}",
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

data "kubernetes_service" "existing_loadbalancers" {
  count = var.expose_app_externally ? 1 : 0

  metadata {
    name      = "check-port-${var.external_port}"
    namespace = "default"
  }
}

resource "null_resource" "check_port_availability" {
  count = var.expose_app_externally ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"
      
      # Check if any LoadBalancer service is using this port
      USED_PORTS=$(kubectl get svc -A -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | .spec.ports[].port')
      
      if echo "$USED_PORTS" | grep -q "^${var.external_port}$"; then
        echo "ERROR: Port ${var.external_port} is already in use by another LoadBalancer service"
        exit 1
      fi
      
      echo "Port ${var.external_port} is available"
    EOT
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

  depends_on = [null_resource.check_port_availability]
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

  depends_on = [null_resource.workflow_eventsource]
}
