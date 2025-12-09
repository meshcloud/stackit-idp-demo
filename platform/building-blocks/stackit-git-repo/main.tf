terraform {
  required_providers {
    gitea = {
      source  = "Lerentis/gitea"
      version = "~> 0.12"
    }
  }
}

provider "gitea" {
  base_url = var.gitea_base_url
  token    = var.gitea_token
}

resource "gitea_repository" "repo" {
  count = var.use_template ? 0 : 1

  username       = var.gitea_organization
  name           = var.repository_name
  description    = var.repository_description
  private        = var.repository_private
  auto_init      = var.repository_auto_init
  default_branch = var.default_branch
}

locals {
  owner = var.gitea_organization
  template_variables = {
    REPO_NAME = var.template_repo_name
    NAMESPACE = var.template_namespace
    CLONE_URL = "${var.gitea_base_url}/${local.owner}/${var.repository_name}.git"
  }
  repo_id        = var.use_template ? "${local.owner}/${var.repository_name}" : gitea_repository.repo[0].id
  repo_name      = var.repository_name
  repo_html_url  = var.use_template ? "${var.gitea_base_url}/${local.owner}/${var.repository_name}" : gitea_repository.repo[0].html_url
  repo_ssh_url   = var.use_template ? "git@${replace(var.gitea_base_url, "https://", "")}:${local.owner}/${var.repository_name}.git" : gitea_repository.repo[0].ssh_url
  repo_clone_url = var.use_template ? "${var.gitea_base_url}/${local.owner}/${var.repository_name}.git" : gitea_repository.repo[0].clone_url
}

resource "null_resource" "template_repo" {
  count = var.use_template ? 1 : 0

  triggers = {
    repo_name      = var.repository_name
    template_owner = var.template_owner
    template_name  = var.template_name
    template_vars  = jsonencode(local.template_variables)
    owner          = local.owner
  }

  provisioner "local-exec" {
    command = <<-EOT
      response=$(curl -s -w "\n%%{http_code}" -X POST "${var.gitea_base_url}/api/v1/repos/${var.template_owner}/${var.template_name}/generate" \
        -H "Authorization: token ${var.gitea_token}" \
        -H "Content-Type: application/json" \
        -d '{
          "owner": "${local.owner}",
          "name": "${var.repository_name}",
          "description": "${var.repository_description}",
          "private": ${var.repository_private},
          "git_content": true,
          "git_hooks": false
        }')
      
      http_code=$(echo "$response" | tail -n1)
      body=$(echo "$response" | sed '$d')
      
      if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "Repository created successfully"
        echo "$body"
      else
        echo "Failed to create repository. HTTP Status: $http_code"
        echo "$body"
        exit 1
      fi
    EOT
  }
}

resource "null_resource" "webhook" {
  count = var.webhook_url != "" ? 1 : 0

  triggers = {
    webhook_url    = var.webhook_url
    webhook_secret = var.webhook_secret
    webhook_events = join(",", var.webhook_events)
    repo_id        = local.repo_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -X POST "${var.gitea_base_url}/api/v1/repos/${local.owner}/${var.repository_name}/hooks" \
        -H "Authorization: token ${var.gitea_token}" \
        -H "Content-Type: application/json" \
        -d '{
          "type": "forgejo",
          "config": {
            "url": "${var.webhook_url}",
            "content_type": "json",
            "secret": "${var.webhook_secret}"
          },
          "events": ${jsonencode(var.webhook_events)},
          "active": true
        }'
    EOT
  }

  depends_on = [gitea_repository.repo, null_resource.template_repo]
}
