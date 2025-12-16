# Technical Debt #

## Harbor Container Registry ##

- IAM not yet fully integrated
- Use robot users for container registry
- To create robot users with terraform, we need to copy the personal CLI secret from the users profile:
  - Log in to Harbor with STACKIT SSO
  - Go to your profile in the upper right corner
  - Copy CLI Secret
  - Put it in terraform.tfvars

**TODO:** Automate Harbor project and robot account creation via Terraform

- Currently: goharbor/harbor provider returns 401 errors despite valid credentials (curl works fine)
- Workaround: Create project and robot accounts manually in Harbor UI, then pass credentials to Terraform as variables
- Future: Investigate provider issue or implement curl-based provisioning in bootstrap module

## git organization onboarding ##

- User does not get access to STACKIT git out of the blue
- Organization onboarding has to be done separately

## git actions ##

- Actions Runner for STACKIT git is currently provided manually and takes up to 2 days
- To make our PoC more lightweigh, we go for a local CI script which builds the container and pushes it into the app env's registry
- ArgoCD picks it up from there and deploys it.
- The credentials for the registry push robot account will be provided by a special building block. The developers need to put it into their personal env files for now.
- Later, we either switch to a STACKIT runner or deploy a custom forgejo runner: https://forgejo.org/docs/latest/admin/actions/runner-installation/ which can be registered in STACKIT git.
