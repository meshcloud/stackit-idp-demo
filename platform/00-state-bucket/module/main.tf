terraform {
  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.68.0"
    }
  }
}

resource "stackit_objectstorage_bucket" "terraform_state" {
  project_id = var.stackit_project_id
  name       = "tfstate-meshstack-backend"
}

resource "stackit_objectstorage_credentials_group" "terraform_state" {
  project_id = var.stackit_project_id
  name       = "terraform-state-access"

  depends_on = [stackit_objectstorage_bucket.terraform_state]
}

resource "stackit_objectstorage_credential" "terraform_state" {
  project_id           = var.stackit_project_id
  credentials_group_id = stackit_objectstorage_credentials_group.terraform_state.credentials_group_id
}
