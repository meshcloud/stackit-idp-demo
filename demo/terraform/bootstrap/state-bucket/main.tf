# STACKIT Object Storage for Terraform State
# ============================================================================
# Creates S3-compatible bucket for storing terraform state files
# This should be applied FIRST before other terraform configurations

terraform {
  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.68.0"
    }
  }
}

provider "stackit" {
  service_account_key_path = "./sa-key-8c3df93c-eec2-4f6d-af77-156731c9ef97.json"
  default_region           = "eu01"
}

# Object Storage Bucket for Terraform State
resource "stackit_objectstorage_bucket" "terraform_state" {
  project_id = var.stackit_project_id
  name       = "tfstate-meshstack-backend"
}

# Credentials Group for managing access
resource "stackit_objectstorage_credentials_group" "terraform_state" {
  project_id = var.stackit_project_id
  name       = "terraform-state-access"

  depends_on = [stackit_objectstorage_bucket.terraform_state]
}

# Access credentials for the bucket
resource "stackit_objectstorage_credential" "terraform_state" {
  project_id           = var.stackit_project_id
  credentials_group_id = stackit_objectstorage_credentials_group.terraform_state.credentials_group_id
}
