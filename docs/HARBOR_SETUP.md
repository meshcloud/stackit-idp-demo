# Harbor Setup for STACKIT Bootstrap

STACKIT Harbor uses **OIDC-only authentication mode**. This means:

- ❌ No local service accounts
- ❌ No global API tokens  
- ✅ OIDC user login (your STACKIT email)
- ✅ CLI Secret as password replacement
- ✅ Robot accounts for CI/CD workflows

## Getting Harbor Credentials

Follow these steps to obtain the credentials needed for Terraform:

### 1. Login to STACKIT Portal
Go to https://portal.stackit.cloud and log in with your STACKIT account.

### 2. Navigate to Harbor
Access Harbor at https://registry.onstackit.cloud (you'll be redirected to OIDC login).

### 3. Get Your CLI Secret
1. Click your **Profile** (top right corner)
2. Select **CLI Secret**
3. Copy the displayed CLI Secret

### 4. Update terraform.tfvars
Edit `demo/terraform/bootstrap/terraform.tfvars`:

```hcl
harbor_username = "your.email@company.com"   # Your STACKIT email
harbor_password = "<CLI Secret from step 3>"  # The copied CLI Secret
```

## How It Works

When you run `terraform apply`:

1. Terraform authenticates to Harbor using your OIDC credentials
2. Creates a Harbor project (e.g., `hello-world`)
3. Creates a robot account (`ci`) with push/pull permissions
4. Outputs robot credentials for use in CI/CD, Docker, ArgoCD, etc.

## Verify Your Credentials

Test your Harbor login locally:

```bash
docker login registry.onstackit.cloud \
  -u your.email@company.com \
  -p "<CLI Secret>"
```

If this succeeds, Terraform will also work.

## Security Notes

- ⚠️ The CLI Secret expires if you don't refresh your OIDC token regularly
- ✅ Robot account credentials (created by Terraform) are persistent
- 🔒 Never commit real credentials to Git—keep `terraform.tfvars` local

## Next Steps

Once credentials are configured:

```bash
cd demo
make bootstrap
```

This will:
- Provision SKE cluster
- Create Harbor project + robot account
- Export kubeconfig
- Output robot credentials for later use
