# STACKIT Configuration
variable "stackit_project_id" {
  type = string
}

variable "stackit_sa_key_path" {
  description = "Path to STACKIT service account key"
  type        = string
}

variable "stackit_region" {
  type    = string
  default = "eu01"
}

# SKE Cluster Configuration
variable "k8s_version" {
  type    = string
  default = "1.29"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "kubeconfig_path" {
  description = "Path where kubeconfig will be written"
  type        = string
  default     = "../../kubeconfig"
}

# Harbor Configuration
variable "harbor_username" {
  description = "Harbor admin username"
  type        = string
  sensitive   = true
}

variable "harbor_cli_secret" {
  description = "Harbor CLI Secret"
  type        = string
  sensitive   = true
}

variable "harbor_robot_username" {
  description = "Harbor robot account username"
  type        = string
  sensitive   = true
}

variable "harbor_robot_token" {
  description = "Harbor robot account token"
  type        = string
  sensitive   = true
}
