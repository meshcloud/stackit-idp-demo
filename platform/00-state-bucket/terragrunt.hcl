include "root" {
  path           = find_in_parent_folders("root.hcl")
  merge_strategy = "deep"
}

# this is only used to create the bucket initial
# use local state to bootstrap the bucket and credentials
remote_state {
  backend = "local"

  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

terraform {
  source = "./module"
}
