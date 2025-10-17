#!/usr/bin/env bash
# 🚀 Wrapper-Skript: Liest Outputs aus dem bootstrap-Stack (terraform/bootstrap)
# und setzt sie als TF_VAR-Umgebungsvariablen für den app-env-Stack (terraform/app-env),
# um eine vollständig entkoppelte, aber automatisierte Verknüpfung herzustellen.
set -euo pipefail

BOOT="terraform/bootstrap"
APP="terraform/app-env"

KUBECONFIG_PATH="$(cd "$BOOT" && terraform output -raw kubeconfig_path)"
REGISTRY_URL="$(cd "$BOOT" && terraform output -raw registry_url || true)"
ROBOT_USER="$(cd "$BOOT" && terraform output -raw harbor_robot_username || true)"
ROBOT_TOKEN="$(cd "$BOOT" && terraform output -raw harbor_robot_token || true)"

# Optional: App-Repo-Name festlegen
APP_REPO="app"
IMAGE_REPOSITORY="${REGISTRY_URL:+${REGISTRY_URL}/${APP_REPO}}"

export TF_VAR_kubeconfig_path="${KUBECONFIG_PATH}"
export TF_VAR_image_repository="${IMAGE_REPOSITORY}"
export TF_VAR_registry_server="registry.stackit.cloud"
export TF_VAR_registry_username="${ROBOT_USER:-}"
export TF_VAR_registry_password="${ROBOT_TOKEN:-}"

cd "$APP"
terraform init
terraform apply -auto-approve
