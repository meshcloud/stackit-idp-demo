variable "harbor_url" {
  type        = string
  description = "e.g. https://registry.onstackit.cloud"
}

variable "username" {
  type        = string
  description = "Harbor user with permission to create projects"
  sensitive   = true
}

variable "password" {
  type        = string
  description = "Password or token for the user"
  sensitive   = true
}

variable "project" {
  type        = string
  description = "Harbor project name, e.g. hello-world"
}
