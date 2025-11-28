output "cluster_name" {
  value = stackit_ske_cluster.main.name
}

output "cluster_id" {
  value = stackit_ske_cluster.main.id
}

output "kubeconfig" {
  value     = stackit_ske_kubeconfig.main.kube_config
  sensitive = true
}

output "kube_host" {
  value     = yamldecode(stackit_ske_kubeconfig.main.kube_config)["clusters"][0]["cluster"]["server"]
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = yamldecode(stackit_ske_kubeconfig.main.kube_config)["clusters"][0]["cluster"]["certificate-authority-data"]
  sensitive = true
}

output "client_certificate" {
  value     = yamldecode(stackit_ske_kubeconfig.main.kube_config)["users"][0]["user"]["client-certificate-data"]
  sensitive = true
}

output "client_key" {
  value     = yamldecode(stackit_ske_kubeconfig.main.kube_config)["users"][0]["user"]["client-key-data"]
  sensitive = true
}

output "kubernetes_version" {
  value = stackit_ske_cluster.main.kubernetes_version_used
}

output "region" {
  value = stackit_ske_cluster.main.region
}

output "project_id" {
  value = stackit_ske_cluster.main.project_id
}

output "console_url" {
  value = "https://portal.stackit.cloud/project/${stackit_ske_cluster.main.project_id}/kubernetes/${stackit_ske_cluster.main.name}"
}
