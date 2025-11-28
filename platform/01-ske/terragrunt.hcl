include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "./module"
}

inputs = {
  k8s_version         = "1.29"
  node_count          = 1
  kubeconfig_out_path = "${get_terragrunt_dir()}/../../kubeconfig"
}
