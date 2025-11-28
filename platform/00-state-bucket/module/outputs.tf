output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = stackit_objectstorage_bucket.terraform_state.name
}

output "bucket_endpoint" {
  description = "S3 endpoint URL"
  value       = "https://object.storage.${var.stackit_region}.onstackit.cloud"
}

output "access_key_id" {
  description = "Access Key ID for bucket access"
  value       = stackit_objectstorage_credential.terraform_state.access_key
  sensitive   = true
}

output "secret_access_key" {
  description = "Secret Access Key for bucket access"
  value       = stackit_objectstorage_credential.terraform_state.secret_access_key
  sensitive   = true
}
