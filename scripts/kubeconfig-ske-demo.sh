#!/usr/bin/env bash
set -euo pipefail

# scripts/kubeconfig-ske-demo.sh
#
# Purpose:
#   Generate a fresh kubeconfig for the STACKIT SKE demo cluster from Terraform/Terragrunt outputs.
#   This avoids relying on stale local kubeconfigs (e.g., expired client certificates or tokens).
#
# Usage:
#   ./scripts/kubeconfig-ske-demo.sh
#   source ./scripts/kubeconfig-ske-demo.sh --export
#
# Notes:
#   - Requires: terragrunt, kubectl
#   - This script does NOT require ClickOps. It reads kubeconfig material from IaC outputs.
#   - The generated kubeconfig is stored in ~/.kube/generated/ by default.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKE_STACK_DIR="${SKE_STACK_DIR:-$REPO_ROOT/platform/01-ske}"

OUT_DIR="${OUT_DIR:-$HOME/.kube/generated}"
OUT_FILE="${OUT_FILE:-$OUT_DIR/ske-demo.kubeconfig}"

MODE="${1:-}"

mkdir -p "$OUT_DIR"

# Ensure required tools are present
command -v terragrunt >/dev/null 2>&1 || { echo "ERROR: terragrunt not found in PATH"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found in PATH"; exit 1; }

echo "==> Generating kubeconfig from Terragrunt outputs"
echo "    Source: $SKE_STACK_DIR"
echo "    Target: $OUT_FILE"

pushd "$SKE_STACK_DIR" >/dev/null

# kubeconfig_ops_team is expected to be an output of platform/01-ske
terragrunt output -raw kubeconfig_ops_team > "$OUT_FILE"

popd >/dev/null

chmod 600 "$OUT_FILE"

echo "==> Verifying cluster connectivity"
KUBECONFIG="$OUT_FILE" kubectl cluster-info >/dev/null

echo "==> OK: kubeconfig is valid."
echo "    To use it for this shell:"
echo "      export KUBECONFIG=\"$OUT_FILE\""
echo "    Or run:"
echo "      KUBECONFIG=\"$OUT_FILE\" kubectl get ns"

# If invoked with --export, print an export command suitable for `source ...`
if [[ "$MODE" == "--export" ]]; then
  # English: Print export statement for the caller's shell
  echo "export KUBECONFIG=\"$OUT_FILE\""
fi
