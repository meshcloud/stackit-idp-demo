variable "harbor_url" {
  type = string
}

variable "harbor_username" {
  type      = string
  sensitive = true
}

variable "harbor_password" {
  type      = string
  sensitive = true
}

variable "platform_project_name" {
  type    = string
  default = "platform-demo"
}

variable "robot_account_name" {
  type    = string
  default = "platform-robot"
}
