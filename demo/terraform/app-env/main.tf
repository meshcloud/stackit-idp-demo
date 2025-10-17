terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

module "argocd" {
  source          = "./modules/argocd"
  kubeconfig_path = var.kubeconfig_path
  namespace       = "argocd"
  auto_sync       = true
}

module "ns" {
  source                  = "./modules/namespace"
  kubeconfig_path         = var.kubeconfig_path
  name                    = var.app_namespace
  create_registry_secret  = true
  registry_server         = var.registry_server
  registry_username       = var.registry_username
  registry_password       = var.registry_password
}

module "app" {
  source                 = "./modules/app-helm"
  kubeconfig_path        = var.kubeconfig_path
  namespace              = module.ns.name
  chart_path             = var.helm_chart_path
  image_repository       = var.image_repository
  image_tag              = var.image_tag
  container_port         = 8080
  service_port           = 80
  image_pull_secret_name = module.ns.image_pull_secret_name
}
