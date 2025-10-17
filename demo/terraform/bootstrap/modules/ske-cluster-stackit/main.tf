# (no provider "stackit" here)
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


resource "stackit_ske_cluster" "this" {
  project_id             = var.project_id
  name                   = "ske-demo"
  kubernetes_version_min = var.k8s_version
  node_pools = [{
    name               = "np1"
    machine_type       = "c2i.2"
    minimum            = var.node_count
    maximum            = var.node_count
    max_surge          = 1
    availability_zones = ["eu01-1"]
    volume_size        = 25
    volume_type        = "storage_premium_perf0"
    labels             = { role = "app" }
    taints             = []
    container_runtime  = "containerd"
    operating_system   = "flatcar"
  }]
  maintenance = {
    enable_kubernetes_version_updates    = true
    enable_machine_image_version_updates = true
    start                                = "02:00:00Z"
    end                                  = "06:00:00Z"
    weekdays                             = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
  }
}

resource "stackit_ske_kubeconfig" "cfg" {
  project_id   = var.project_id
  cluster_name = stackit_ske_cluster.this.name
  expiration   = 3600
  refresh      = true
}

resource "local_file" "kubeconfig" {
  filename = var.kubeconfig_out_path
  content  = stackit_ske_kubeconfig.cfg.kube_config
}
