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
  }
}

provider "stackit" {
  # make auth explicit so we don't rely on the provider's default (~/.stackit/credentials.json)
  service_account_key_path         = var.stackit_sa_key_path
  default_region                   = var.stackit_region
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

module "registry" {
  source     = "./modules/registry-stackit"
  project_id = var.stackit_project_id
  repo_name  = var.app_name
}

module "harbor" {
  source   = "./modules/registry-harbor"
  harbor_url = "https://registry.onstackit.cloud"
  username   = var.harbor_username
  password   = var.harbor_password
  project    = var.app_name           # z.B. "hello-world"
}
