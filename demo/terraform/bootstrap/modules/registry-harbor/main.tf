terraform {
  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "~> 3.9"
    }
  }
}

provider "harbor" {
  url      = var.harbor_url            # https://registry.onstackit.cloud
  username = var.username              # set via TF_VAR_username or env var
  password = var.password
}

resource "harbor_project" "p" {
  name   = var.project
  public = false                       # privat lassen (Demo: true möglich)
}

# Robot Account mit Push/Pull
resource "harbor_robot_account" "ci" {
  name        = "ci"
  description = "Tiny CI push/pull"
  level       = "project"
  project_id  = harbor_project.p.id
  permissions {
    kind      = "project"
    namespace = harbor_project.p.name
    access {
      resource = "repository"
      action   = "push"
    }
    access {
      resource = "repository"
      action   = "pull"
    }
  }
}
