# State Bucket Module

This module creates or connects to the S3-compatible STACKIT Object Storage bucket that stores Terraform state for all platform modules.

## Quick Start

**First, read `SETUP_GUIDE.md` - pick your scenario (Greenfield or Brownfield).**

---

## Prerequisites

Your `.env` must have:
```bash
STACKIT_PROJECT_ID="your-project-id"
STACKIT_SERVICE_ACCOUNT_KEY_PATH="/path/to/sa-key.json"
```

For existing buckets, also add:
```bash
AWS_ACCESS_KEY_ID="existing-key"
AWS_SECRET_ACCESS_KEY="existing-secret"
```

---

## State Management

This module uses **local state** (stored in `terraform.tfstate` locally) instead of remote S3 state because of a bootstrap chicken-and-egg problem:
- Before the bucket exists, we can't store state IN the bucket
- This module is only run once to bootstrap the infrastructure

The local state file is **NOT committed to git** for security reasons.

### Handling Existing Resources

If the resources already exist (e.g., deploying on an existing platform), you have two options:

**Option 1: Import existing resources (recommended if you have the IDs)**

Get the resource IDs from STACKIT UI or CLI, then import them:

```bash
PROJECT_ID="272f2ba5-fa0a-4b8b-8ceb-e68165a87914"
REGION="eu01"
BUCKET_NAME="tfstate-meshstack-backend"
CREDENTIALS_GROUP_ID="<get-from-stackit-ui>"
CREDENTIAL_ID="<get-from-stackit-ui>"

# Import them
terragrunt import stackit_objectstorage_bucket.terraform_state "$PROJECT_ID,$REGION,$BUCKET_NAME"
terragrunt import stackit_objectstorage_credentials_group.terraform_state "$PROJECT_ID,$REGION,$CREDENTIALS_GROUP_ID"
terragrunt import stackit_objectstorage_credential.terraform_state "$PROJECT_ID,$REGION,$CREDENTIALS_GROUP_ID,$CREDENTIAL_ID"

# Now apply is idempotent
terragrunt apply
```

**Option 2: Create NEW credentials for existing bucket (quick & simple)**

If you don't know the existing resource IDs:

```bash
# Try apply (will fail on bucket creation)
terragrunt apply -auto-approve

# Remove the failed bucket resource from state
terragrunt state rm stackit_objectstorage_bucket.terraform_state

# Apply again - this time only credentials group and credential are created
terragrunt apply -auto-approve

# Get the new credentials
terragrunt output -raw access_key_id
terragrunt output -raw secret_access_key
```

This creates **new credentials for the existing bucket**, which is safe because:
- Multiple credential sets can exist in the same credentials group
- You can have old and new credentials active simultaneously
- This is useful for credential rotation

---

## What Gets Created

1. **Object Storage Bucket**: `tfstate-meshstack-backend`
   - Location: STACKIT Object Storage (eu01)
   - Purpose: Stores Terraform state for all other modules
   - Encryption: Enabled

2. **Credentials Group**: `terraform-state-access`
   - Purpose: Organizes access credentials

3. **Access Credential**: S3-compatible key/secret
   - Purpose: Allows Terraform to read/write state to the bucket
   - Format: AWS S3 compatible credentials (not actual AWS)

- Create bucket manually via STACKIT Portal/CLI
- Never manage with Terraform
- Document manual setup steps

## Next Steps

After deploying the bucket:
1. Export AWS credentials (see above)
2. Deploy platform modules in order:
   ```bash
   cd ../01-ske && terragrunt apply
   cd ../02-harbor && terragrunt apply
   cd ../03-meshstack && terragrunt apply
   cd ../04-argocd && terragrunt apply
   ```
