output "repo_https_url" {
  description = "HTTPS URL for cloning the repository"
  value       = gitea_repository.state_repo.clone_url
}

output "repo_ssh_url" {
  description = "SSH URL for cloning the repository"
  value       = gitea_repository.state_repo.ssh_url
}

output "repo_html_url" {
  description = "Web URL to view the repository"
  value       = gitea_repository.state_repo.html_url
}

output "repo_name" {
  description = "Name of the created repository"
  value       = gitea_repository.state_repo.name
}

output "repo_full_path" {
  description = "Full path of the repository (organization/name)"
  value       = "${gitea_repository.state_repo.username}/${gitea_repository.state_repo.name}"
}
