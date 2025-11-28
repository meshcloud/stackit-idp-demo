variable "kube_host" {
  type      = string
  sensitive = true
}

variable "cluster_ca_certificate" {
  type      = string
  sensitive = true
}

variable "bootstrap_client_certificate" {
  type      = string
  sensitive = true
}

variable "bootstrap_client_key" {
  type      = string
  sensitive = true
}
