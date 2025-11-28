include "root" {
  path = find_in_parent_folders()
  
  merge_strategy = "shallow"
}

remote_state {
  backend = "local"
  
  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
}

terraform {
  source = "./module"
}
