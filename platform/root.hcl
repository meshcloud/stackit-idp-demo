remote_state {
  backend = "s3"
  
  # Skip remote state for 00-state-bucket bootstrap module
  # It uses local state to avoid chicken-and-egg problem
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
    if        = !strcontains(get_terragrunt_dir(), "/00-state-bucket")
  }
  
  config = {
    bucket = "tfstate-meshstack-backend"
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = "eu01"
    
    endpoint                    = "https://object.storage.eu01.onstackit.cloud"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
    
    encrypt = true
  }
}

locals {
  stackit_project_id = get_env("STACKIT_PROJECT_ID")
  stackit_region     = "eu01"
}

inputs = {
  stackit_project_id   = local.stackit_project_id
  stackit_region       = local.stackit_region
  stackit_sa_key_path  = get_env("STACKIT_SERVICE_ACCOUNT_KEY_PATH", "~/.stackit/sa-key.json")
}
