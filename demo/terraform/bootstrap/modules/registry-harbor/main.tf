terraform {
  required_version = ">= 1.0"
}

# This module currently acts as a data/output pass-through for Harbor credentials.
# In the future, this should be replaced with direct Harbor provider integration
# once authentication issues are resolved (see TECHNICAL_DEBT.md).
#
# For now, Harbor project and robot account must be created manually via the Harbor UI.
