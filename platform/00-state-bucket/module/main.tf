terraform {
  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.68.0"
    }
  }
}

provider "stackit" {
  service_account_key_path = var.stackit_sa_key_path
  default_region           = var.stackit_region
}

# Try to create the bucket
# If it already exists (409), Terraform will fail but state won't be updated
# See SETUP_GUIDE.md Scenario 3 for how to handle this
resource "stackit_objectstorage_bucket" "terraform_state" {
  project_id = var.stackit_project_id
  name       = "tfstate-meshstack-backend"
}

# Create credentials group
# No depends_on - this allows it to be created independently
# If bucket creation failed, you should manually delete the bucket from state
# $ terragrunt state rm stackit_objectstorage_bucket.terraform_state
resource "stackit_objectstorage_credentials_group" "terraform_state" {
  project_id = var.stackit_project_id
  name       = "terraform-state-access"

  # We removed depends_on to allow this to work even if bucket creation failed
  # This works because the bucket already exists in STACKIT
  # depends_on = [stackit_objectstorage_bucket.terraform_state]
}

# Create credentials for the bucket
# This works whether the credentials_group was newly created or already existed
resource "stackit_objectstorage_credential" "terraform_state" {
  project_id           = var.stackit_project_id
  credentials_group_id = stackit_objectstorage_credentials_group.terraform_state.credentials_group_id
}
