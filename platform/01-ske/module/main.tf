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
  service_account_key_path = var.stackit_sa_key_path
  default_region           = var.stackit_region
}

module "ske" {
  source = "../../../demo/terraform/bootstrap/modules/ske-cluster-stackit"

  project_id          = var.stackit_project_id
  region              = var.stackit_region
  k8s_version         = var.k8s_version
  node_count          = var.node_count
  kubeconfig_out_path = var.kubeconfig_out_path

  providers = {
    stackit = stackit
    local   = local
  }
}
