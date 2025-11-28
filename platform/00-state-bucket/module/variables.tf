variable "stackit_project_id" {
  description = "STACKIT Project ID"
  type        = string
}

variable "stackit_region" {
  description = "STACKIT Region"
  type        = string
  default     = "eu01"
}

variable "stackit_sa_key_path" {
  description = "Path to STACKIT service account key file"
  type        = string
}
