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

variable "cluster_name" {
  type    = string
  default = "ske-demo"
}

variable "k8s_version" {
  type    = string
  default = "1.29"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "nodepool_name" {
  type    = string
  default = "np1"
}

variable "machine_type" {
  type    = string
  default = "c2i.2"
}

variable "availability_zones" {
  type    = list(string)
  default = ["eu01-1"]
}

variable "volume_size" {
  type    = number
  default = 25
}

variable "volume_type" {
  type    = string
  default = "storage_premium_perf0"
}

variable "maintenance_start" {
  type    = string
  default = "02:00:00Z"
}

variable "maintenance_end" {
  type    = string
  default = "06:00:00Z"
}

variable "enable_kubernetes_version_updates" {
  type    = bool
  default = true
}

variable "enable_machine_image_version_updates" {
  type    = bool
  default = true
}
