include "root" {
  path           = find_in_parent_folders("root.hcl") # Add filename explicitly
  merge_strategy = "deep"
}

# this is only used to create the bucket initial
# 
# remote_state {
#   backend = "local"

#   config = {
#     path = "${get_terragrunt_dir()}/terraform.tfstate"
#   }

#   generate = {
#     path      = "backend.tf"
#     if_exists = "overwrite"
#   }
# }

terraform {
  source = "./module"
}
