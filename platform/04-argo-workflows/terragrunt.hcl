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
  argo_workflows_namespace = "argo-workflows"
  argo_workflows_version   = "0.42.5"
  argo_events_version      = "2.4.8"
}
