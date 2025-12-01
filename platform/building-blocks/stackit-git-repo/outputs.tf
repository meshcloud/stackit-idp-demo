output "repository_id" {
  value       = local.repo_id
  description = "The ID of the created repository"
}

output "repository_name" {
  value       = local.repo_name
  description = "The name of the created repository"
}

output "repository_html_url" {
  value       = local.repo_html_url
  description = "Web URL of the repository"
}

output "repository_ssh_url" {
  value       = local.repo_ssh_url
  description = "SSH clone URL"
}

output "repository_clone_url" {
  value       = local.repo_clone_url
  description = "HTTPS clone URL"
}

output "deploy_key_id" {
  value       = length(gitea_repository_key.deploy_key) > 0 ? gitea_repository_key.deploy_key[0].id : null
  description = "The ID of the deploy key (if created)"
}
