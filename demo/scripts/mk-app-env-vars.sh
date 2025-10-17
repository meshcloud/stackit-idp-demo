#!/usr/bin/env bash
# 🧩 Generator-Skript: Erstellt eine handover.auto.tfvars.json-Datei
# mit allen benötigten Eingabeparametern aus dem bootstrap-Stack.
# Diese Datei dient als sauberer Input-Contract für terraform/app-env.
set -euo pipefail

BOOT="terraform/bootstrap"
APP="terraform/app-env"

KUBECONFIG_PATH="$(cd "$BOOT" && terraform output -raw kubeconfig_path)"
REGISTRY_URL="$(cd "$BOOT" && terraform output -raw registry_url || true)"
ROBOT_USER="$(cd "$BOOT" && terraform output -raw harbor_robot_username || true)"
ROBOT_TOKEN="$(cd "$BOOT" && terraform output -raw harbor_robot_token || true)"

APP_REPO="app"
IMAGE_REPOSITORY="${REGISTRY_URL:+${REGISTRY_URL}/${APP_REPO}}"

cat >"${APP}/handover.auto.tfvars.json" <<JSON
{
  "kubeconfig_path": "${KUBECONFIG_PATH}",
  "image_repository": "${IMAGE_REPOSITORY}",
  "registry_server": "registry.stackit.cloud",
  "registry_username": "${ROBOT_USER}",
  "registry_password": "${ROBOT_TOKEN}"
}
JSON

echo "Wrote ${APP}/handover.auto.tfvars.json"

