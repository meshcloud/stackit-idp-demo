include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "./module"
}

dependency "ske" {
  config_path = "../01-ske"
}

inputs = {
  harbor_url      = "https://registry.onstackit.cloud"
  harbor_username = get_env("HARBOR_USERNAME")
  harbor_password = get_env("HARBOR_CLI_SECRET")
  
  platform_project_name = "platform-demo"
  robot_account_name    = "platform-robot"
}
