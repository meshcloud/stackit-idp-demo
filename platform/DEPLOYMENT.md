# Platform Deployment Guide

Complete step-by-step guide to deploy the STACKIT IDP platform.

## ⚠️ Important: Bootstrap First

You **MUST** complete **Phase 0** before deploying any other components. Phase 0 creates the S3 bucket where all subsequent modules store their Terraform state.

---

## Phase 0: State Bucket Access

**→ Read `platform/00-state-bucket/SETUP_GUIDE.md` and follow it completely.**

This phase ensures you can access the state bucket. Choose ONE of three scenarios:

1. **Scenario 1 (Greenfield)**: Creating a new state bucket from scratch
2. **Scenario 2 (Brownfield with Credentials)**: Connecting to existing bucket using S3 credentials
3. **Scenario 3 (Brownfield Auto-Generate)**: Generating new S3 credentials using STACKIT access

**Quick Decision:**
- New platform? → Scenario 1
- Platform exists + have S3 credentials? → Scenario 2
- Platform exists + only have STACKIT credentials? → Scenario 3

After completing Phase 0, you should have `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in your `.env`.

Then proceed to Phase 1 below.

---

## Phase 1: Deploy Platform Components

After Phase 0 is complete, you have the S3 bucket and credentials. Now deploy the platform.

### Step 1: Ensure .env is fully configured

Your `.env` must have all credentials from Phase 0:

```bash
# In platform/.env should now be:
STACKIT_PROJECT_ID="272f2ba5-fa0a-4b8b-8ceb-e68165a87914"
STACKIT_SERVICE_ACCOUNT_KEY_PATH="~/.stackit/sa-key.json"
AWS_ACCESS_KEY_ID="<from-phase-0>"
AWS_SECRET_ACCESS_KEY="<from-phase-0>"
```

### Step 2: Deploy SKE Cluster

```bash
cd platform/01-ske
terragrunt plan
terragrunt apply

terragrunt output cluster_name
```

**Wait ~15 minutes for SKE cluster provisioning.**

### Step 3: Deploy Harbor Registry

```bash
cd ../02-harbor
terragrunt plan
terragrunt apply

terragrunt output registry_url
```

### Step 4: Deploy meshStack Integration

```bash
cd ../03-meshstack
terragrunt plan
terragrunt apply

terragrunt output
```

### Step 5: Deploy ArgoCD

```bash
cd ../04-argocd
terragrunt plan
terragrunt apply

terragrunt output argocd_namespace
```

**Wait ~5 minutes for ArgoCD LoadBalancer.**

### Step 6: Get ArgoCD URL

```bash
kubectl get svc -n argocd argocd-server

export ARGOCD_URL=$(kubectl get svc -n argocd argocd-server \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "ArgoCD: http://$ARGOCD_URL"
```

Login with:
- Username: `admin`
- Password: (from `ARGOCD_ADMIN_PASSWORD_BCRYPT` environment variable)

## Phase 2: Onboard First Application

### Option A: Use Building Block Directly

```bash
mkdir -p platform/namespaces/demo-app
cd platform/namespaces/demo-app
```

Create `terragrunt.hcl`:
```hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../building-blocks/namespace-with-argocd"
}

dependency "ske" {
  config_path = "../../01-ske"
}

dependency "harbor" {
  config_path = "../../02-harbor"
}

dependency "argocd" {
  config_path = "../../04-argocd"
}

inputs = {
  namespace_name = "demo-app"
  tenant_name    = "demo"
  project_name   = "demo"

  github_repo_url        = "https://github.com/YOUR_ORG/demo-app"
  github_target_revision = "main"
  github_manifests_path  = "manifests/overlays/dev"

  harbor_robot_username = dependency.harbor.outputs.robot_username
  harbor_robot_token    = dependency.harbor.outputs.robot_token
}
```

```bash
terragrunt plan
terragrunt apply
```

### Option B: Use Blueprint Repository

1. **Create GitHub repository from blueprint:**
   ```bash
   cp -r app-repo-blueprint ../demo-app-repo
   cd ../demo-app-repo
   git init
   git remote add origin https://github.com/YOUR_ORG/demo-app
   ```

2. **Configure GitHub secrets:**
   - `HARBOR_USERNAME`: Get from `cd platform/02-harbor && terragrunt output robot_username`
   - `HARBOR_PASSWORD`: Get from Harbor UI or robot account
   - `HARBOR_PROJECT`: `platform-demo`

3. **Update manifests:**
   ```bash
   sed -i 's/NAMESPACE_NAME/demo-app/g' manifests/overlays/dev/kustomization.yaml
   sed -i 's/HARBOR_PROJECT/platform-demo/g' manifests/overlays/dev/kustomization.yaml
   ```

4. **Push to GitHub:**
   ```bash
   git add .
   git commit -m "Initial platform demo app"
   git push -u origin main
   ```

5. **GitHub Actions will:**
   - Build Docker image
   - Push to Harbor
   - ArgoCD syncs manifests to namespace

## Phase 3: Verify Deployment

### Check Platform Status

```bash
cd platform
terragrunt run-all output
```

### Check Kubernetes Resources

```bash
export KUBECONFIG=platform/kubeconfig

kubectl get nodes
kubectl get namespaces
kubectl get applications -n argocd
kubectl get pods -n demo-app
```

### Check ArgoCD

Open ArgoCD UI: `http://$ARGOCD_URL`

Should see:
- Application `demo-app` in healthy/synced state

### Test Application

```bash
kubectl port-forward -n demo-app svc/platform-demo 8080:80
curl http://localhost:8080/health
```

## Phase 4: Integrate with meshStack

### Configure Building Block in meshStack

1. **Create Building Block Definition** in meshStack:
   - Type: Terraform
   - Source: Point to `platform/building-blocks/namespace-with-argocd`

2. **Define Inputs**:
   - `namespace_name`: From meshProject ID
   - `tenant_name`: From meshTenant ID
   - `github_repo_url`: User input
   - `harbor_robot_username`: From platform outputs
   - `harbor_robot_token`: From platform outputs

3. **Assign to Landing Zone**:
   - Attach building block to SKE platform
   - Teams can order via self-service

### Test Self-Service Flow

1. Team orders namespace via meshStack portal
2. meshStack runs Building Block Terraform
3. Namespace created with ArgoCD Application
4. Team pushes code → GitHub Actions → Harbor → ArgoCD → Deployed

## Monitoring

### Platform Health

```bash
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running
kubectl top nodes
kubectl top pods -A
```

### ArgoCD Sync Status

```bash
kubectl get applications -n argocd
argocd app list
argocd app get demo-app
```

### Harbor Status

```bash
curl https://registry.onstackit.cloud/api/v2.0/health
```

## Cleanup (Destroy Platform)

**⚠️ WARNING: This destroys all resources**

```bash
cd platform
terragrunt run-all destroy --terragrunt-non-interactive
```

Destroy order (automatic via Terragrunt dependency graph):
1. Namespaces (all apps)
2. ArgoCD
3. meshStack
4. Harbor
5. SKE Cluster

## Common Issues

### Issue: SKE cluster not ready
**Solution:** Wait 15-20 minutes after apply

### Issue: ArgoCD can't pull from GitHub
**Solution:** 
- Check GitHub repo is public OR
- Add SSH key to ArgoCD: `kubectl create secret -n argocd`

### Issue: Pods can't pull from Harbor
**Solution:**
- Verify `harbor-pull-secret` exists in namespace
- Check robot account credentials in Harbor UI

### Issue: Terragrunt dependency errors
**Solution:**
```bash
terragrunt run-all init
rm -rf .terragrunt-cache
terragrunt run-all plan
```

## Next Steps

- [ ] Add Ingress controller (NGINX/Traefik)
- [ ] Configure DNS for ArgoCD
- [ ] Add monitoring (Prometheus/Grafana)
- [ ] Implement backup strategy
- [ ] Configure ApplicationSet for auto-discovery
- [ ] Add policy enforcement (OPA/Kyverno)
