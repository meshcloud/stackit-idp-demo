variable "stackit_project_id" {
  type = string
}

variable "stackit_sa_key_path" {
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
  default = 1
}

variable "kubeconfig_out_path" {
  type = string
}
