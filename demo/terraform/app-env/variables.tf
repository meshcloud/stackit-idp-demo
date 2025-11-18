variable "kubeconfig_path" {
  type = string
}

variable "app_namespace" {
  type    = string
  default = "demo-app"
}

variable "image_repository" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "bootstrap"
}

variable "helm_chart_path" {
  type    = string
  default = "../chart"
}

variable "registry_server" {
  type    = string
  default = "registry.stackit.cloud"
}

variable "registry_username" {
  type    = string
  default = ""
}

variable "registry_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "harbor_url"      { type = string }
variable "harbor_username" { 
  type = string 
  sensitive = true 
}
variable "harbor_password" { 
  type = string
  sensitive = true 
}

variable "app_name"        { type = string }
