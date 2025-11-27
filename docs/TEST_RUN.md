# Test Run: Provision → Configure → App-Env Deployment

Complete workflow to validate the three-layer architecture from ADR-002.

## Architecture Overview

```
PROVISION LAYER (bootstrap/platform/provision)
├─ SKE Cluster + Harbor Registry
└─ Outputs: kube_host, cluster_ca_certificate, bootstrap_client_certificate, bootstrap_client_key
    ↓ [inject-provision-to-configure.py]

CONFIGURE LAYER (bootstrap/platform/configure)
├─ Kubernetes provider (certificate-based auth)
├─ platform-admin namespace
├─ platform-terraform ServiceAccount + ClusterRole
├─ Kubernetes Secret with long-lived token
└─ Outputs: app_env_kube_host, app_env_kube_ca_certificate, app_env_kube_token
    ↓ [inject-configure-to-appenv.py]

APP-ENV LAYER (app-env)
├─ Kubernetes provider (token-based auth)
├─ demo-app namespace with ResourceQuota + LimitRange + NetworkPolicies
└─ Outputs: namespace_name, namespace_id
```

## Prerequisites

```bash
# 1. Verify you're in the right directory
cd /Users/joerg/repos/stackit-idp-demo/demo

# 2. Check Makefile and configs
ls -la Makefile
ls -la terraform/bootstrap/platform/provision/
ls -la terraform/bootstrap/platform/configure/
ls -la terraform/app-env/
```

## Step 1: Validate All Layers

```bash
make validate
```

**Expected Output:**

```
🔍 Validating Provision layer...
✅ Bootstrap/Provision valid

🔍 Validating Configure layer...
✅ Bootstrap/Configure valid

🔍 Validating App-Env layer...
✅ App-Env valid

✅ All layers valid
```

## Step 2: Deploy Provision Layer (~12 minutes)

```bash
make provision
```

**What happens:**
- Terraform init in `bootstrap/platform/provision`
- Creates SKE cluster (~9-10 minutes)
- Configures Harbor Registry (~1-2 minutes)
- Outputs credentials for Configure layer

**Expected Output:**

```
🚀 Phase A: Provisioning infrastructure...

terraform apply -auto-approve

... creating resources ...

✅ Provision layer deployed
```

## Step 3: Deploy Configure Layer (~3 minutes)

```bash
make configure
```

**What the Makefile does:**
1. Checks Provision state exists
2. Runs `inject-provision-to-configure.py` to extract outputs
3. Creates `terraform/bootstrap/platform/configure/terraform.auto.tfvars.json`
4. Deploys Configure layer with credential injection

**Expected Output:**

```
✅ Provision state found
📝 Injecting Provision outputs into Configure...
✅ Outputs injected

🚀 Phase B: Configuring platform...

terraform apply -auto-approve

... creating RBAC, ServiceAccount, Secret ...

✅ Configuration layer deployed
```

## Step 4: Deploy App-Env Layer (~2 minutes)

```bash
make app-env
```

**What the Makefile does:**
1. Checks Configure state exists
2. Runs `inject-configure-to-appenv.py` to extract token
3. Creates `terraform/app-env/terraform.auto.tfvars.json`
4. Deploys App-Env with token-based authentication

**Expected Output:**

```
✅ Configure state found
📝 Injecting Configure outputs into App-Env...
✅ Outputs injected

🚀 Phase C: Deploying application environment...

terraform apply -auto-approve

... creating namespace, quotas, policies ...

✅ App-Env layer deployed
```

## Step 5: Test Cluster Connectivity

### Option A: Automated Tests

```bash
make test-connection
```

**Expected Output:**

```
✅ Configure state found
🔑 Generating kubeconfig with platform-terraform token...
✅ kubeconfig generated: /tmp/kubeconfig-token

🧪 Testing kubectl connectivity...
  → cluster-info...
    ⚠ Cluster info available
  → namespaces...
    ✓ demo-app namespace found
  → resourcequota...
    ✓ ResourceQuota configured
  → networkpolicies...
    ✓ NetworkPolicies configured

✅ All connection tests passed
```

### Option B: Manual Testing with kubectl

```bash
# Generate kubeconfig
make kubeconfig

# Set kubeconfig
export KUBECONFIG=/tmp/kubeconfig-token

# Verify resources
kubectl get ns
kubectl get ns demo-app
kubectl get resourcequota -n demo-app
kubectl get networkpolicies -n demo-app
```

## Complete One-Shot Script

```bash
#!/bin/bash
set -e

cd /Users/joerg/repos/stackit-idp-demo/demo

echo "🚀 Starting full deployment..."
echo ""

# Step 1: Validate
echo "📋 Step 1: Validating..."
make validate
echo ""

# Step 2: Deploy Provision
echo "⏳ Step 2: Deploying Provision (~12 min)..."
make provision
echo ""

# Step 3: Deploy Configure
echo "⏳ Step 3: Deploying Configure (~3 min)..."
make configure
echo ""

# Step 4: Deploy App-Env
echo "⏳ Step 4: Deploying App-Env (~2 min)..."
make app-env
echo ""

# Step 5: Test
echo "🧪 Step 5: Testing connectivity..."
make test-connection
echo ""

echo "✅ ✅ ✅ Full deployment successful! ✅ ✅ ✅"
echo ""
echo "Next: Test with kubectl"
echo "  make kubeconfig"
echo "  export KUBECONFIG=/tmp/kubeconfig-token"
echo "  kubectl get ns demo-app"
```

## Expected Time

| Step | Duration | Notes |
|------|----------|-------|
| `make validate` | ~2 sec | Fast |
| `make provision` | ~12 min | 9-10 min SKE, 1-2 min Harbor |
| `make configure` | ~3 min | RBAC + ServiceAccount |
| `make app-env` | ~2 min | Namespace + Quotas + Policies |
| `make test-connection` | ~5 sec | Automated tests |
| **Total** | **~18 min** | From zero to fully deployed |

## Troubleshooting

### Provision fails: "no provider configured"

**Cause:** STACKIT credentials not set in `terraform.tfvars`

**Fix:**

```bash
cd terraform/bootstrap/platform/provision
cat terraform.tfvars
```

### Configure fails: "Unauthorized"

**Cause:** Provision credentials not injected properly

**Fix:**

```bash
# Check if terraform.auto.tfvars.json was created
cat terraform/bootstrap/platform/configure/terraform.auto.tfvars.json

# Re-run injection
python3 scripts/inject-provision-to-configure.py

# Then retry
make configure
```

### App-Env fails: "Unauthorized"

**Cause:** Configure credentials not injected properly

**Fix:**

```bash
# Check injection
cat terraform/app-env/terraform.auto.tfvars.json

# Re-run injection
python3 scripts/inject-configure-to-appenv.py

# Then retry
make app-env
```

## For Tomorrow's Demo

**Preparation (today if possible):**

```bash
make provision
make configure
make app-env
make down  # Clean up
```

This validates the entire workflow works. Tomorrow run:

```bash
make provision && make configure && make app-env && make test-connection
```

Then:

```bash
make kubeconfig
export KUBECONFIG=/tmp/kubeconfig-token
kubectl get ns demo-app
```

**Total demo time:** ~20 minutes
