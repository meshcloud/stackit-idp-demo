# State Bucket Setup - Choose Your Path

This directory has three scenarios. **Pick one and follow it:**

## Scenario 1: State Bucket DOES NOT EXIST YET (Greenfield)

Use this if you're setting up a brand new platform.

```bash
cd platform/00-state-bucket

# 1. Load environment
set -a
source ../.env
set +a

# 2. Deploy
terragrunt init
terragrunt apply

# 3. Save credentials to .env
export AWS_ACCESS_KEY_ID=$(terragrunt output -raw access_key_id)
export AWS_SECRET_ACCESS_KEY=$(terragrunt output -raw secret_access_key)
echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> ../.env
echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> ../.env

# Done! Proceed to Phase 1
```

---

## Scenario 2: Bucket EXISTS + You Have S3 Credentials (Brownfield with Credentials)

Use this if the platform already exists AND someone gave you the S3 credentials.

### Step 1: Add credentials to .env

```bash
cd platform
nano .env
```

Add these lines:
```
AWS_ACCESS_KEY_ID=your-existing-access-key
AWS_SECRET_ACCESS_KEY=your-existing-secret
```

### Step 2: Verify

```bash
cd 00-state-bucket
set -a
source ../.env
set +a

terragrunt init
terragrunt state list

# If you see "aws_s3_bucket.terraform_state" listed, ✅ you're connected!
```

### Step 3: Done!

Your state bucket is configured. Proceed to Phase 1.

---

## Scenario 3: Bucket EXISTS + You ONLY Have STACKIT Credentials (Brownfield Auto-Generate)

Use this if the platform exists but nobody gave you the S3 credentials. You only have STACKIT project ID + service account key.

**This scenario generates NEW S3 credentials for the existing bucket.**

### Step 1: Ensure STACKIT credentials are set

```bash
cd platform
nano .env
```

Verify you have:
```
STACKIT_PROJECT_ID=your-project-id
STACKIT_SERVICE_ACCOUNT_KEY_PATH=/path/to/sa-key.json
```

### Step 2: Try to create new credentials

```bash
cd 00-state-bucket
set -a
source ../.env
set +a

terragrunt apply -auto-approve
```

This will fail at the bucket creation (409 - already exists) but that's expected.

### Step 3: Remove failed bucket from state

```bash
terragrunt state rm stackit_objectstorage_bucket.terraform_state
```

This tells Terraform to forget about the bucket so it can create credentials for it.

### Step 4: Create the credentials

```bash
terragrunt apply -auto-approve
```

This time it will succeed! You'll have:
- ✅ New credentials group
- ✅ New S3 credentials

### Step 5: Save credentials to .env

```bash
export AWS_ACCESS_KEY_ID=$(terragrunt output -raw access_key_id)
export AWS_SECRET_ACCESS_KEY=$(terragrunt output -raw secret_access_key)
echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> ../.env
echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> ../.env
```

### Step 6: Done!

Your state bucket is now accessible. Proceed to Phase 1.

**Note:** You've created NEW credentials. The old ones still exist in STACKIT and should be cleaned up later.

---

## Which scenario applies to me?

- **Scenario 1**: You're the first person deploying this platform
- **Scenario 2**: The platform exists AND someone shared the S3 credentials with you
- **Scenario 3**: The platform exists BUT nobody has the S3 credentials (or they're lost/rotated) AND you have STACKIT access

**Decision tree:**
```
Does the platform already exist?
├─ No → Scenario 1
└─ Yes
   ├─ Do you have S3 credentials? → Scenario 2
   └─ No, but you have STACKIT access → Scenario 3
```

---

## Troubleshooting

### "aws_s3_bucket.terraform_state not found" after `terragrunt state list`

Your credentials are wrong (Scenario 2). Double-check `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

### "bucket already exists" error on first try

You're in Scenario 1 but the bucket exists → use Scenario 3 instead.

### "terraform state rm failed"

Make sure you're in the right directory: `cd platform/00-state-bucket`

### "401 Unauthorized" when creating credentials

Your STACKIT credentials are wrong. Check `STACKIT_PROJECT_ID` and `STACKIT_SERVICE_ACCOUNT_KEY_PATH`.

