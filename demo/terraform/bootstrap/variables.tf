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

variable "stackit_sa_key_path" {
  description = "Path to the STACKIT service-account key JSON"
  type        = string
}

variable "harbor_username" {
  description = "Harbor admin username (your STACKIT email for OIDC login, kept for future automation)"
  type        = string
  sensitive   = true
}

variable "harbor_cli_secret" {
  description = "Harbor CLI Secret (get from STACKIT Portal → Harbor Profile → CLI Secret)"
  type        = string
  sensitive   = true
}

variable "harbor_robot_username" {
  description = "Harbor robot account username (created manually in Harbor UI)"
  type        = string
  sensitive   = true
}

variable "harbor_robot_token" {
  description = "Harbor robot account secret token (created manually in Harbor UI)"
  type        = string
  sensitive   = true
}