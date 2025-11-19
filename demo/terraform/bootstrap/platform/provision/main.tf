# Platform Provision Layer (Phase A)
# ============================================================================
# Creates platform infrastructure: SKE cluster, Harbor registry
# No Kubernetes provider — only cloud control plane APIs
# 
# Outputs feed into Platform Configuration Layer (Phase B)

terraform {
  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.68.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.0"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "~> 3.9"
    }
  }
}

provider "stackit" {
  service_account_key_path = var.stackit_sa_key_path
  default_region           = var.stackit_region
}

provider "harbor" {
  url      = "https://registry.onstackit.cloud"
  username = var.harbor_username
  password = var.harbor_cli_secret
}

# SKE Cluster (infrastructure only, no K8s provider)
module "ske" {
  source = "../../../bootstrap/modules/ske-cluster-stackit"

  project_id          = var.stackit_project_id
  region              = var.stackit_region
  k8s_version         = var.k8s_version
  node_count          = var.node_count
  kubeconfig_out_path = var.kubeconfig_path

  providers = {
    stackit = stackit
    local   = local
  }
}

# Harbor Registry
module "harbor" {
  source = "../../../bootstrap/modules/registry-harbor"

  harbor_url          = "https://registry.onstackit.cloud"
  harbor_username     = var.harbor_username
  harbor_password     = var.harbor_cli_secret
  project             = "platform-demo"
  robot_username      = var.harbor_robot_username
  robot_token         = var.harbor_robot_token
}
