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

output "summary" {
  description = "Summary with next steps and insights into created resources"
  value       = <<-EOT
# Git Repository Created

✅ **Your Git repository is ready!**

## Repository Details

- **Name**: ${var.repository_name}
- **Owner**: ${local.owner}
- **URL**: ${local.repo_html_url}
- **Clone URL**: `${local.repo_clone_url}`

## Next Steps

1. **Clone your repository**:
   ```bash
   git clone ${local.repo_clone_url}
   cd ${var.repository_name}
   ```

2. **Start developing**: Edit `app/main.py` with your application logic

3. **Push your changes**:
   ```bash
   git add .
   git commit -m "Your commit message"
   git push origin ${var.default_branch}
   ```

${var.webhook_url != "" ? "## Webhook Configured\n\nPushes to this repository will trigger builds at:\n- **Webhook URL**: `${var.webhook_url}`\n- **Events**: ${join(", ", var.webhook_events)}" : ""}

## Resources

- View repository: [${local.repo_html_url}](${local.repo_html_url})
EOT
}
