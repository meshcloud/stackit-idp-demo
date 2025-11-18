terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}

# Use local-exec to install Argo CD via Helm CLI
# This avoids complex Terraform Kubernetes/Helm provider configuration issues
resource "null_resource" "argocd_install" {
  triggers = {
    kubeconfig_path = var.kubeconfig_path
    argocd_version  = var.argocd_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KUBECONFIG="${var.kubeconfig_path}"
      
      # Add Argo CD Helm repo
      helm repo add argoproj https://argoproj.github.io/argo-helm
      helm repo update
      
      # Create argocd namespace
      kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
      
      # Install Argo CD via Helm
      helm upgrade --install argocd argoproj/argo-cd \
        --namespace argocd \
        --version ${var.argocd_version} \
        --set server.service.type=LoadBalancer \
        --set server.insecure=true \
        --wait
    EOT
    
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
  }
}

# Verify Argo CD is running
resource "null_resource" "argocd_verify" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KUBECONFIG="${var.kubeconfig_path}"
      
      echo "Waiting for Argo CD server deployment..."
      kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
      
      echo "Argo CD successfully deployed!"
    EOT
    
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
  }

  depends_on = [null_resource.argocd_install]
}
