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

module "ske" {
  source               = "./modules/ske-cluster-stackit"
  project_id           = var.stackit_project_id
  region               = var.stackit_region
  k8s_version          = var.k8s_version
  node_count           = var.node_count
  kubeconfig_out_path  = var.kubeconfig_path

  providers = {
    stackit = stackit
    local   = local
  }
}

# NOTE: registry-stackit is a stub/dummy - no actual resources
# Will be replaced when STACKIT integrates Harbor natively
# module "registry" {
#   source     = "./modules/registry-stackit"
#   project_id = var.stackit_project_id
#   repo_name  = var.app_name
# }

# Harbor module - passes through manually-created Harbor project and robot credentials
# NOTE: harbor_username and harbor_password are passed for future automation (see TECHNICAL DEBT)
module "harbor" {
  source         = "./modules/registry-harbor"
  harbor_url     = "https://registry.onstackit.cloud"
  harbor_username = var.harbor_username
  harbor_password = var.harbor_cli_secret
  project        = "platform-demo"
  robot_username = var.harbor_robot_username
  robot_token    = var.harbor_robot_token
}
