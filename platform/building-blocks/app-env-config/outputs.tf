# Outputs to inform users of the Building Block execution result

output "gitops_path" {
  description = "Path in the GitOps state repository where release.yaml was written"
  value       = local.gitops_path
}

output "release_yaml_path" {
  description = "Full path to the committed release.yaml file"
  value       = local.release_yaml_path
}

output "image_reference" {
  description = "The container image reference that was committed (repository@digest or repository:tag)"
  value       = local.image_reference
}

output "commit_message" {
  description = "The Git commit message used for this release update"
  value       = local.commit_message
}

output "state_repo_url" {
  description = "HTTPS URL of the GitOps state repository"
  value       = local.git_clone_url
}

output "deployment_flow" {
  description = "Summary of the deployment flow triggered by this Building Block"
  value = <<-EOT
    Release updated successfully!
    
    The following changes were committed to the GitOps state repository:
    - Repository: ${local.git_clone_url}
    - File: ${local.release_yaml_path}
    - Image: ${local.image_reference}
    
    Next steps:
    1. ArgoCD will detect the Git change on the main branch
    2. ArgoCD will render the Helm chart with the new image reference
    3. The application will be deployed to the target Kubernetes namespace
    4. Monitor the deployment status via ArgoCD or kubectl
  EOT
}
