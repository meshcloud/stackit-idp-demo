include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "./module"
}

dependency "ske" {
  config_path = "../01-ske"
  
  mock_outputs = {
    kube_host                    = "https://mock-k8s-api.local"
    cluster_ca_certificate       = "bW9jaw=="
    bootstrap_client_certificate = "bW9jaw=="
    bootstrap_client_key         = "bW9jaw=="
  }
}

inputs = {
  kube_host                    = dependency.ske.outputs.kube_host
  cluster_ca_certificate       = dependency.ske.outputs.cluster_ca_certificate
  bootstrap_client_certificate = dependency.ske.outputs.bootstrap_client_certificate
  bootstrap_client_key         = dependency.ske.outputs.bootstrap_client_key
  
  argocd_namespace    = "argocd"
  argocd_version      = "7.7.5"
  admin_password_bcrypt = get_env("ARGOCD_ADMIN_PASSWORD_BCRYPT", "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/XGN1YGcDFzfbEG")
}
