terraform {
  source = "./module"
}

remote_state {
  backend = "local"
  
  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
}

inputs = {
  stackit_project_id = get_env("STACKIT_PROJECT_ID")
  stackit_region     = "eu01"
}
