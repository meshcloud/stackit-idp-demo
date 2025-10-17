variable "stackit_project_id" {
  type = string
}

variable "stackit_region" {
  type    = string
  default = "eu01"
}

variable "k8s_version" {
  type    = string
  default = "1.29"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "kubeconfig_path" {
  description = "Filesystem path where the module should write kubeconfig"
  type        = string
  default     = "../kubeconfig"
}

variable "app_name" {
  type    = string
  default = "hello-world"
}

variable "stackit_sa_key_path" {
  description = "Path to the STACKIT service-account key JSON"
  type        = string
}

# bootstrap/variables.tf
variable "harbor_username" {
  type      = string
  sensitive = true
}

variable "harbor_password" {
  type      = string
  sensitive = true
}

