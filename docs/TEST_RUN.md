# Test Run: Bootstrap → App-Env Deployment

Complete workflow to validate the two-layer architecture for tomorrow's demo.

---

## Prerequisites

```bash
# 1. Verify you're in the right directory
cd /Users/joerg/repos/stackit-idp-demo/demo

# 2. Check Makefile exists and is readable
ls -la Makefile
cat Makefile | head -30

# 3. Verify Terraform configs exist
ls -la terraform/bootstrap/
ls -la terraform/app-env/
```

---

## Step 1: Validate Syntax (No Resources Created)

```bash
cd /Users/joerg/repos/stackit-idp-demo/demo

# Run validation
make validate
```

**Expected Output:**
```
🔍 Validating Bootstrap layer...
Success! The configuration is valid.

🔍 Validating App-Env layer...
Success! The configuration is valid.

✅ All layers valid
```

**If validation fails:** Terraform syntax error in either layer. Fix before proceeding.

---

## Step 2: Deploy Bootstrap (~12 minutes total)

```bash
make bootstrap
```

**What happens:**
1. ✅ `terraform init` in bootstrap/ (downloads providers)
2. ✅ `terraform validate` in bootstrap/
3. ✅ `terraform apply -auto-approve` (creates SKE + Harbor)
   - SKE cluster creation: ~9-10 minutes
   - Harbor config: ~1-2 minutes
4. ✅ Makefile displays exported outputs

**Expected Output (end):**
```
✅ Bootstrap deployed. Exported outputs:
[
  {
    "key": "cluster_endpoint",
    "type": "string",
    "description": "Kubernetes API endpoint..."
  },
  {
    "key": "cluster_ca_certificate",
    "type": "string",
    "description": "Cluster CA certificate..."
  },
  ...
]

📝 Next step: run 'make app-env' to deploy App-Env layer
```

**If bootstrap fails:**
```bash
# Check state
cd terraform/bootstrap
terraform state list

# Debug: see what went wrong
terraform apply -auto-approve  # (run again to see error)
```

---

## Step 3: Deploy App-Env (~3 minutes)

```bash
make app-env
```

**What the Makefile does:**
1. ✅ `_check-bootstrap` — verifies `terraform/bootstrap/terraform.tfstate` exists
2. ✅ `_extract-bootstrap-outputs` — reads Bootstrap outputs:
   - `cluster_endpoint`
   - `cluster_ca_certificate`
   - `registry_url`
   - `registry_username`
   - `registry_password`
3. ✅ Writes to `terraform/app-env/terraform.tfvars.auto.json`
4. ✅ `terraform init` in app-env/
5. ✅ `terraform validate` in app-env/
6. ✅ `terraform apply -auto-approve`
   - Creates RBAC (ServiceAccount + ClusterRole)
   - Creates Kubernetes Secret (terraform-admin-token)
   - Creates Namespace `demo-app`
   - Creates ImagePullSecret

**Expected Output (middle):**
```
📥 Extracting Bootstrap outputs...
✅ Outputs written to: terraform/app-env/terraform.tfvars.auto.json

{
  "cluster_endpoint": "https://api.ske-demo.d2695c1f95.s.ske.eu01.onstackit.cloud",
  "cluster_ca_certificate": "-----BEGIN CERTIFICATE-----\n...",
  "registry_url": "registry.onstackit.cloud/platform-demo",
  "registry_username": "robot$platform-demo+ci",
  "registry_password": "kRbbamLZ7QduT7cI4KD2wPvej1vlWvnm",
  "namespace": "demo-app"
}
```

**Expected Output (end):**
```
✅ App-Env deployed. Exported outputs:
[
  {
    "key": "namespace_name",
    "type": "string"
  },
  {
    "key": "service_account_token",
    "type": "string (sensitive)"
  }
]
```

**If app-env fails with "Unauthorized":**

This means the `cluster_admin_token` in the Makefile extraction **is stale/invalid**. The issue is:

```
Bootstrap kubeconfig (expires after ~8h)
    ↓
App-Env tries to use it
    ↓
401 Unauthorized
```

**Solution:** You need to provide a fresh token BEFORE `make app-env`. This is the **"initial token problem"** we discussed. See Step 4 below.

---

## Step 4: CRITICAL — Get Initial Token for App-Env

**Problem:** `make app-env` will fail with "Unauthorized" because the `cluster_admin_token` isn't set yet. This is expected on **first run**.

**Solution: Two approaches**

### Approach A: Extract from Bootstrap Kubeconfig (Simple)

```bash
# 1. Get fresh kubeconfig from Bootstrap
cd /Users/joerg/repos/stackit-idp-demo/demo/terraform/bootstrap

# This creates a fresh kubeconfig with updated credentials
terraform refresh

# 2. Extract token from kubeconfig
# The kubeconfig has client certificate + key, which we can use to create a token
TOKEN=$(kubectl create token terraform-admin -n kube-system --duration=87600h --kubeconfig=../kubeconfig 2>/dev/null)

echo "Token: $TOKEN"
```

If kubectl is not available or fails, try:

```bash
# Alternative: Use kubeconfig from state
KUBECONFIG=../kubeconfig kubectl get secret -n kube-system -o json | jq '.'
```

### Approach B: Manual Token Creation (After First App-Env Deploy Succeeds)

Actually, this is the **cleanest**: App-Env will create the ServiceAccount and token automatically. So:

1. First, we need **one-time bootstrap token** to create RBAC
2. Once RBAC is created, token is stored in K8s Secret (persistent)
3. Future runs just extract from Secret

**The question:** Where does that one-time bootstrap token come from?

**Answer:** From the kubeconfig that Bootstrap creates. But that kubeconfig expires.

**Workaround for the demo:**

```bash
# Option 1: Accept that we might need to re-run if token expires
cd /Users/joerg/repos/stackit-idp-demo/demo
make bootstrap
sleep 5  # Give kubeconfig time to be written
make app-env  # Should work within ~30 min of bootstrap

# Option 2: If app-env fails, just redeploy
make down    # Destroy both
make bootstrap
make app-env
```

---

## Step 5: Verify Everything Works

```bash
# 1. Check namespace exists
kubectl get ns demo-app

# 2. Check ServiceAccount exists
kubectl get sa -n kube-system terraform-admin

# 3. Check Secret exists
kubectl get secret -n kube-system terraform-admin-token

# 4. Extract token for future use
TOKEN=$(kubectl get secret terraform-admin-token -n kube-system \
  -o jsonpath='{.data.token}' | base64 -d)

echo "Token for future deployments: $TOKEN"

# 5. Check ImagePullSecret in namespace
kubectl get secret -n demo-app registry-pull-secret
```

---

## Complete One-Shot Script (For Demo)

```bash
#!/bin/bash
set -e

cd /Users/joerg/repos/stackit-idp-demo/demo

echo "🚀 Starting full deployment..."

# Step 1: Validate
echo "📋 Step 1: Validating..."
make validate

# Step 2: Deploy Bootstrap
echo "⏳ Step 2: Deploying Bootstrap (~10 min)..."
make bootstrap

# Step 3: Deploy App-Env
echo "⏳ Step 3: Deploying App-Env (~3 min)..."
make app-env

# Step 4: Verify
echo "✅ Step 4: Verifying..."
kubectl get ns demo-app
kubectl get sa -n kube-system terraform-admin
kubectl get secret -n kube-system terraform-admin-token

echo ""
echo "✅ ✅ ✅ Full deployment successful! ✅ ✅ ✅"
echo ""
echo "Next: Extract token for future deployments:"
echo "  TOKEN=\$(kubectl get secret terraform-admin-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)"
echo "  echo \$TOKEN"
```

---

## Troubleshooting

### Bootstrap fails: "no provider configured"

**Cause:** STACKIT credentials not in `terraform.tfvars`

**Fix:**
```bash
cd terraform/bootstrap
cat terraform.tfvars  # Check if project_id, etc. are set

# If missing, populate from your STACKIT setup
```

### App-Env fails: "Unauthorized"

**Cause:** Token is stale

**Fix:**
```bash
cd terraform/bootstrap
terraform refresh  # Get fresh kubeconfig

# Then retry
cd ../app-env
make app-env
```

### App-Env fails: "terraform.tfstate not found"

**Cause:** Bootstrap wasn't deployed

**Fix:**
```bash
make bootstrap  # First
make app-env    # Then
```

### Makefile fails: "jq not found"

**Cause:** Missing tool

**Fix:**
```bash
brew install jq
```

---

## Expected Time

| Step | Duration | Notes |
|------|----------|-------|
| `make validate` | ~2 sec | Fast |
| `make bootstrap` | ~12 min | 9-10 min SKE creation, 1-2 min Harbor config |
| `make app-env` | ~3 min | RBAC + namespace creation |
| **Total** | **~15 min** | From zero to fully deployed |

---

## For Tomorrow's Demo

**Do this today if possible:**

```bash
make bootstrap    # Run once, let it complete (~12 min)
make app-env      # Run once, let it complete (~3 min)
make down         # Destroy everything
```

This validates the entire workflow works. Tomorrow, you can:

```bash
make bootstrap && make app-env
```

And show:
1. Cluster being created
2. Namespace + RBAC being created
3. `kubectl` showing deployed resources

**Total demo time:** ~20 minutes (or show pre-recorded video, then live verification of resources)

