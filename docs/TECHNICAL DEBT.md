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
