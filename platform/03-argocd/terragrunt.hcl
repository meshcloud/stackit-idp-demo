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

# ADR-004: GitOps state repository must be provisioned before ArgoCD
# ArgoCD ApplicationSet watches this repository for application environments
dependency "gitops_state_repo" {
  config_path = "../05-gitops-state-repo"
  
  mock_outputs = {
    repo_ssh_url                   = "git@git-service.git.onstackit.cloud:platform/app-environments.git"
    gitops_tenant_path_template    = "workspaces/{workspace_id}/projects/{project_id}/tenants/{tenant_id}"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  # Use explicit cluster credentials from SKE module instead of kubeconfig file
  # This prevents storing sensitive tokens on disk during Terraform execution
  kubernetes_host                   = dependency.ske.outputs.kube_host
  kubernetes_cluster_ca_certificate = dependency.ske.outputs.cluster_ca_certificate
  # kubernetes_token                  = get_env("TF_VAR_kubernetes_token")
  kubernetes_client_certificate     = dependency.ske.outputs.client_certificate
  kubernetes_client_key             = dependency.ske.outputs.client_key
  
  harbor_url            = get_env("TF_VAR_harbor_url")
  harbor_robot_username = get_env("TF_VAR_harbor_robot_username")
  harbor_robot_token    = get_env("TF_VAR_harbor_robot_token")
  
  # ADR-004: Consume GitOps state repository URL from 05-gitops-state-repo
  gitops_state_repo_url = dependency.gitops_state_repo.outputs.repo_ssh_url
}
