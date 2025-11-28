# Platform Deployment Guide

Step-by-step guide to deploy the STACKIT IDP platform.

## Phase 1: State Bucket (Already Complete)

✅ S3 bucket for Terraform state already exists:
- Bucket: `tfstate-meshstack-backend`
- Endpoint: `https://object.storage.eu01.onstackit.cloud`

## Phase 2: Deploy Platform Components

### Step 1: Configure Environment

```bash
export STACKIT_PROJECT_ID="your-project-id"
export STACKIT_SERVICE_ACCOUNT_KEY_PATH="~/.stackit/sa-key.json"
export HARBOR_USERNAME="admin"
export HARBOR_CLI_SECRET="your-harbor-password"
```

Generate ArgoCD admin password (bcrypt):
```bash
htpasswd -nbBC 10 admin YourPassword | cut -d: -f2
export ARGOCD_ADMIN_PASSWORD_BCRYPT="generated-hash"
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

## Phase 3: Onboard First Application

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

## Phase 4: Verify Deployment

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

## Phase 5: Integrate with meshStack

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
