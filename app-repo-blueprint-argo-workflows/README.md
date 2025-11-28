# App Repo Blueprint - Argo Workflows

This blueprint demonstrates how to use **Argo Workflows + Argo Events** to build a fully Kubernetes-native CI/CD pipeline that listens to **STACKIT Git Service** webhooks and builds container images without external CI tools like GitHub Actions.

## Architecture

```
STACKIT Git Service (git.stackit.cloud)
         ↓ (webhook on push)
    EventSource (webhook receiver)
         ↓
    Sensor (triggers workflow)
         ↓
    Workflow (Kaniko build)
         ↓
    Harbor Registry (image pushed)
         ↓
    ArgoCD (deploys app)
```

## Prerequisites

1. **Platform deployed** with Argo Workflows + Events:
   ```bash
   cd platform/04-argo-workflows
   terragrunt apply
   ```

2. **STACKIT Git Service** repository created

3. **Harbor** registry access (robot account)

4. **SSH key** for STACKIT Git Service access

## Setup Instructions

### 1. Create Secrets

#### Git SSH Key Secret
```bash
kubectl create secret generic git-ssh-key \
  --from-file=ssh-private-key=$HOME/.ssh/id_rsa \
  -n argo
```

#### Harbor Pull Secret (if not already created by platform)
```bash
kubectl create secret docker-registry harbor-pull-secret \
  --docker-server=harbor.example.com \
  --docker-username='robot$myproject+myrobot' \
  --docker-password=YOUR_ROBOT_TOKEN \
  -n argo
```

### 2. Deploy Argo Resources

```bash
# Apply EventSource, Sensor, and WorkflowTemplate
kubectl apply -f argo-manifests/
```

### 3. Configure STACKIT Git Webhook

Get the EventSource service endpoint:
```bash
kubectl get svc -n argo

# Expose EventSource (for demo - use Ingress in production)
kubectl port-forward svc/stackit-git-eventsource-svc 12000:12000 -n argo
```

In STACKIT Git Service:
1. Go to **Settings → Webhooks**
2. Add webhook:
   - **URL**: `http://YOUR_EXTERNAL_IP:12000/push`
   - **Events**: Push events
   - **Content type**: `application/json`

### 4. Customize Workflow Parameters

Edit `argo-manifests/sensor.yaml` to match your setup:

```yaml
parameters:
  - name: repo-url
    value: "git@git.stackit.cloud:YOUR_PROJECT/YOUR_REPO.git"
  - name: image-name
    value: "harbor.example.com/YOUR_PROJECT/YOUR_APP"
  - name: image-tag
    value: "latest"  # Or use commit SHA from webhook
```

### 5. Test the Pipeline

```bash
# Push to STACKIT Git
git add .
git commit -m "Trigger build"
git push origin main

# Watch workflow execution
kubectl get workflows -n argo -w

# View logs
kubectl logs -n argo -l workflows.argoproj.io/workflow=build-image-xxxxx
```

## Files Explanation

### `argo-manifests/eventsource.yaml`
Defines the webhook endpoint that receives events from STACKIT Git Service.

### `argo-manifests/sensor.yaml`
Listens to EventSource and triggers a Workflow when a push event occurs.

### `argo-manifests/workflow-template.yaml`
Reusable template that:
1. Clones code from STACKIT Git
2. Builds Docker image with Kaniko
3. Pushes to Harbor registry

### `app/`
Your application code (FastAPI example included).

## Workflow Execution

When you push to STACKIT Git:

1. **Webhook triggers** EventSource
2. **Sensor receives** event and extracts git ref/commit
3. **Workflow created** from WorkflowTemplate
4. **Kaniko builds** image from Dockerfile
5. **Image pushed** to Harbor
6. **ArgoCD syncs** (if configured to watch image tags)

## Production Considerations

### 1. Expose EventSource via Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argo-events-webhook
  namespace: argo
spec:
  rules:
    - host: webhooks.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: stackit-git-eventsource-svc
                port:
                  number: 12000
```

### 2. Use Commit SHA as Image Tag

Modify sensor to extract commit SHA:
```yaml
parameters:
  - src:
      dependencyName: stackit-git-push
      dataKey: body.after  # Git commit SHA
    dest: spec.arguments.parameters.3.value  # image-tag parameter
```

### 3. Webhook Security

Add webhook secret validation in EventSource:
```yaml
webhook:
  stackit-git-push:
    port: "12000"
    endpoint: /push
    method: POST
    filter:
      expression: "headers['X-Gitlab-Token'][0] == 'YOUR_SECRET_TOKEN'"
```

### 4. Resource Limits

Add to WorkflowTemplate:
```yaml
container:
  image: gcr.io/kaniko-project/executor:latest
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

## Comparison: Argo Workflows vs GitHub Actions

| Feature | Argo Workflows | GitHub Actions |
|---------|---------------|----------------|
| **Location** | Runs in your K8s cluster | Runs on GitHub runners |
| **Git Service** | Any Git (STACKIT, GitLab, etc.) | GitHub only |
| **Secrets** | K8s Secrets | GitHub Secrets |
| **Cost** | Free (your cluster) | Free tier + paid |
| **Control** | Full control | Limited to GitHub |

## Troubleshooting

### Workflow Not Triggered
```bash
kubectl logs -n argo -l eventsource-name=stackit-git
kubectl logs -n argo -l sensor-name=stackit-git-sensor
```

### Build Fails
```bash
# Check workflow status
kubectl get workflow -n argo

# View logs
kubectl logs -n argo <workflow-pod-name>
```

### Git Clone Fails
```bash
# Verify SSH key secret
kubectl get secret git-ssh-key -n argo -o yaml

# Test SSH connection manually
ssh -T git@git.stackit.cloud
```

### Image Push Fails
```bash
# Verify Harbor credentials
kubectl get secret harbor-pull-secret -n argo -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
```

## Next Steps

1. **ArgoCD Integration**: Configure ArgoCD to watch image tags
2. **Multi-environment**: Use different WorkflowTemplates for dev/staging/prod
3. **Notifications**: Add Slack/email notifications on build success/failure
4. **Security scanning**: Add Trivy image scanning step
5. **Caching**: Enable Kaniko cache for faster builds

## Support

- Argo Workflows docs: https://argo-workflows.readthedocs.io
- Argo Events docs: https://argoproj.github.io/argo-events
- Kaniko docs: https://github.com/GoogleContainerTools/kaniko
