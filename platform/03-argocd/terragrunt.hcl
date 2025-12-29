include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "./module"
}

dependency "ske" {
  config_path = "../01-ske"
  
  mock_outputs = {
    kube_host                     = "https://mock-kube-host"
    cluster_ca_certificate        = "bW9jay1jZXJ0aWZpY2F0ZQ=="
    client_certificate            = "bW9jay1jbGllbnQtY2VydA=="
    client_key                    = "bW9jay1jbGllbnQta2V5"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  # Use explicit cluster credentials from SKE module instead of kubeconfig file
  # This prevents storing sensitive tokens on disk during Terraform execution
  kubernetes_host                   = dependency.ske.outputs.kube_host
  kubernetes_cluster_ca_certificate = dependency.ske.outputs.cluster_ca_certificate
  kubernetes_token                  = get_env("TF_VAR_kubernetes_token")
  
  harbor_url            = get_env("TF_VAR_harbor_url")
  harbor_robot_username = get_env("TF_VAR_harbor_robot_username")
  harbor_robot_token    = get_env("TF_VAR_harbor_robot_token")
}
