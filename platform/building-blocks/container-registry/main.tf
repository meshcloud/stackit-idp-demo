# Container Registry Building Block (v1 - Placeholder)
# Computes deterministic image repository path for container images.
# No actual registry provisioning, auth, or external providers.

locals {
  # Compute the full image repository path from components
  image_repository = "${var.registry_base}/${var.harbor_project}/${var.workspace_id}/${var.project_id}/${var.tenant_id}/${var.app_name}"

  # Example tags for documentation and copy-paste workflows
  image_example_tag    = "${local.image_repository}:release"
  image_example_digest = "${local.image_repository}@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}
