variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "k8s_version" {
  type = string
  default = "1.33.5"
}

variable "node_count" {
  type = number
}

variable "kubeconfig_out_path" {
  description = "Where to write kubeconfig on disk"
  type        = string
}
