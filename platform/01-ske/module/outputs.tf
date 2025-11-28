output "cluster_name" {
  value = module.ske.cluster_name
}

output "cluster_id" {
  value = module.ske.cluster_id
}

output "kube_host" {
  value     = module.ske.kube_host
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = module.ske.cluster_ca_certificate
  sensitive = true
}

output "bootstrap_client_certificate" {
  value     = module.ske.bootstrap_client_certificate
  sensitive = true
}

output "bootstrap_client_key" {
  value     = module.ske.bootstrap_client_key
  sensitive = true
}
