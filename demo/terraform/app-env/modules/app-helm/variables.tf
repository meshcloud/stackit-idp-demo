variable "kubeconfig_path" {
  type = string
}

variable "namespace" {
  type = string
}

variable "chart_path" {
  type = string
}

variable "image_repository" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "service_port" {
  type    = number
  default = 80
}

variable "kubeconfig_path" {
  type = string
}

variable "namespace" {
  type = string
}

variable "chart_path" {
  type = string
}

variable "image_repository" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "service_port" {
  type    = number
  default = 80
}

variable "image_pull_secret_name" {
  description = "Name of a dockerconfigjson secret to add to pod imagePullSecrets"
  type        = string
  default     = ""
}
