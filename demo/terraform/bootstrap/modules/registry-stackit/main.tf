# NOTE (transparent): as of the current STACKIT provider, there is
# no dedicated Container Registry resource. We expose a computed
# registry URL that you can docker login/push to.
#
# If STACKIT ships a CR resource later, we can drop it in here and
# keep the same outputs/variables.

locals {
  # Adjust base if your project/region uses a different hostname
  registry_base = "registry.stackit.cloud"
}

# No resources created here (yet). You create/populate the repo by docker push.
