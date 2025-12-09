# State Bucket Module

This module creates the S3-compatible STACKIT Object Storage bucket that stores Terraform state for all other platform modules.

## ⚠️ Important: Deploy This First

This module **MUST** be deployed before any other platform components because:
- It creates the `tfstate-meshstack-backend` bucket
- All other modules (01-ske, 02-harbor, etc.) store their state in this bucket
- This module uses **local state** (not remote S3 state)

## Prerequisites

### Option A: Source from .env file

```bash
# Copy and customize environment template
cp ../env.example ../.env
# Edit .env with real values
nano ../.env

# Load environment variables
set -a
source ../.env
set +a
```

### Option B: Manual export

```bash
export STACKIT_PROJECT_ID="your-project-id"
export STACKIT_SERVICE_ACCOUNT_KEY_PATH="~/.stackit/sa-key.json"
```

## Deployment

```bash
cd platform/00-state-bucket
terragrunt init
terragrunt apply
```

## Outputs

After deployment, you'll receive:
- `bucket_name`: `tfstate-meshstack-backend`
- `bucket_endpoint`: `https://object.storage.eu01.onstackit.cloud`
- `access_key_id`: S3 access key (sensitive)
- `secret_access_key`: S3 secret key (sensitive)

## Configure AWS Credentials

Export the credentials for other modules to use:

```bash
# Get the credentials
export AWS_ACCESS_KEY_ID=$(terragrunt output -raw access_key_id)
export AWS_SECRET_ACCESS_KEY=$(terragrunt output -raw secret_access_key)

# Add to your environment or .env file
echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> ../env.example
echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> ../env.example
```

## What Gets Created

1. **Object Storage Bucket**: `tfstate-meshstack-backend`
2. **Credentials Group**: `terraform-state-access` 
3. **Access Credential**: S3-compatible access key/secret

## State Storage

This module stores its state **locally** in:
```
platform/00-state-bucket/terraform.tfstate
```

### ⚠️ Bootstrap State Management

This creates a **bootstrap problem**: 
- The bucket's state is stored locally (can't use S3 before bucket exists)
- State file is **NOT committed to git** (security best practice)
- Each team member must handle state independently

**Options for team collaboration:**

**Option 1: Single owner (recommended for small teams)**
- One person deploys and manages the state bucket
- Others never touch this module
- Outputs are shared via `.env` file

**Option 2: Import existing resources**
If you need to manage the bucket from a new machine:
```bash
terragrunt import stackit_objectstorage_bucket.terraform_state "PROJECT_ID,REGION,BUCKET_NAME"
terragrunt import stackit_objectstorage_credentials_group.terraform_state "PROJECT_ID,REGION,GROUP_ID"
terragrunt import stackit_objectstorage_credential.terraform_state "PROJECT_ID,REGION,GROUP_ID,CRED_ID"
```

**Option 3: Manual creation (production recommended)**
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
