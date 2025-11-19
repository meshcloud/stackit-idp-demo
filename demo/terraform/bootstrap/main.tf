terraform {
  required_version = ">= 1.13.4"
}

# ============================================================================
# NOTE: All infrastructure is now managed in bootstrap/platform/
# This directory contains ONLY the platform/ subdirectory structure
# 
# To deploy:
# 1. make provision      (creates SKE cluster + Harbor registry)
# 2. make configure      (initializes Kubernetes + RBAC)
# 3. make app-env        (deploys application namespace + policies)
#
# See: docs/adr/ADR-002_bootstrap-platform-components.md
# ============================================================================
