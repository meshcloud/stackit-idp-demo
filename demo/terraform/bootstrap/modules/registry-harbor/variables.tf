variable "harbor_url" {
  description = "Harbor base URL, e.g. https://registry.onstackit.cloud"
  type        = string
}

variable "harbor_username" {
  description = "Harbor user with permission to create projects (currently unused, kept for future automation)"
  type        = string
  sensitive   = true
}

variable "harbor_password" {
  description = "Harbor password/CLI secret (currently unused, kept for future automation)"
  type        = string
  sensitive   = true
}

variable "project" {
  description = "Harbor project name that was created manually"
  type        = string
}

variable "robot_username" {
  description = "Robot account username (created manually in Harbor UI)"
  type        = string
  sensitive   = true
}

variable "robot_token" {
  description = "Robot account secret token (created manually in Harbor UI)"
  type        = string
  sensitive   = true
}
