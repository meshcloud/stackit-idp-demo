include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "./module"
}

dependency "ske" {
  config_path = "../01-ske"
}

generate "kubeconfig" {
  path      = "kubeconfig.yaml"
  if_exists = "overwrite"
  contents  = dependency.ske.outputs.kubeconfig
}

inputs = {
  harbor_url            = get_env("TF_VAR_harbor_url")
  harbor_robot_username = get_env("TF_VAR_harbor_robot_username")
  harbor_robot_token    = get_env("TF_VAR_harbor_robot_token")
}
