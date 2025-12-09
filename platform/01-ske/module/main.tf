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

resource "stackit_ske_cluster" "main" {
  project_id = var.stackit_project_id
  name       = var.cluster_name
  node_pools = [
    {
      name               = var.nodepool_name
      machine_type       = var.machine_type
      minimum            = var.node_count
      maximum            = var.node_count
      availability_zones = var.availability_zones
      volume_size        = var.volume_size
      volume_type        = var.volume_type
    }
  ]
  maintenance = {
    enable_kubernetes_version_updates    = var.enable_kubernetes_version_updates
    enable_machine_image_version_updates = var.enable_machine_image_version_updates
    start                                = var.maintenance_start
    end                                  = var.maintenance_end
  }

  lifecycle {
    ignore_changes = [kubernetes_version_used, node_pools[0].os_version_used]
  }
}

resource "stackit_ske_kubeconfig" "main" {
  project_id   = var.stackit_project_id
  cluster_name = stackit_ske_cluster.main.name
  expiration   = "15552000"
  refresh      = true
}

resource "stackit_ske_kubeconfig" "ops_team" {
  project_id   = var.stackit_project_id
  cluster_name = stackit_ske_cluster.main.name
  expiration   = "15552000"
  refresh      = true
}
