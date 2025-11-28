terraform {
  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "~> 3.9"
    }
  }
}

provider "harbor" {
  url      = var.harbor_url
  username = var.harbor_username
  password = var.harbor_password
}

module "harbor" {
  source = "../../../demo/terraform/bootstrap/modules/registry-harbor"

  harbor_url      = var.harbor_url
  harbor_username = var.harbor_username
  harbor_password = var.harbor_password
  project         = var.platform_project_name
  robot_username  = var.harbor_username
  robot_token     = var.harbor_password
}
