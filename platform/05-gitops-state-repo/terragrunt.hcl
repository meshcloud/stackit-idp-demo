include "root" {
  path           = find_in_parent_folders("root.hcl")
  merge_strategy = "deep"
}

terraform {
  source = "./module"
}

inputs = {
  gitea_base_url       = get_env("TF_VAR_gitea_base_url", "")
  gitea_token          = get_env("TF_VAR_gitea_token", "")
  gitea_organization   = get_env("TF_VAR_gitea_organization", "")
  state_repo_name      = get_env("TF_VAR_state_repo_name", "stackit-idp-state")
  default_branch       = get_env("TF_VAR_default_branch", "main")
}
