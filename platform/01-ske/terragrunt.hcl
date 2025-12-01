include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "./module"
}

inputs = {
  cluster_name                         = "ske-demo"
  k8s_version                          = "1.33.5"
  node_count                           = 2
  nodepool_name                        = "np1"
  machine_type                         = "c2i.2"
  availability_zones                   = ["eu01-1"]
  volume_size                          = 25
  volume_type                          = "storage_premium_perf0"
  maintenance_start                    = "02:00:00Z"
  maintenance_end                      = "06:00:00Z"
  enable_kubernetes_version_updates    = true
  enable_machine_image_version_updates = true
  kubeconfig_out_path                  = "${get_terragrunt_dir()}/../../kubeconfig"
}
