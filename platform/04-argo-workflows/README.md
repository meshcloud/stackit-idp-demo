# Argo Workflows Module

Deploys **Argo Workflows** and **Argo Events** to enable Kubernetes-native CI/CD pipelines.

## What Gets Deployed

1. **Argo Workflows** - Workflow engine for orchestrating container builds
2. **Argo Events** - Event-driven workflow automation
3. **NATS JetStream** - Message queue for event processing
4. **Service Accounts & RBAC** - Permissions for workflow execution

## Prerequisites

```bash
# STACKIT credentials
export STACKIT_PROJECT_ID="your-project-id"
export STACKIT_SERVICE_ACCOUNT_KEY_PATH="/path/to/sa-key.json"

# S3 backend credentials
export AWS_ACCESS_KEY_ID="your-s3-access-key"
export AWS_SECRET_ACCESS_KEY="your-s3-secret-key"
```

## Deployment

```bash
cd platform/04-argo-workflows
terragrunt init
terragrunt apply
```

## Post-Deployment Setup

### 1. Deploy WorkflowTemplate for Kaniko Builds

The platform includes a reusable WorkflowTemplate for building images:

```bash
# Copy from blueprint
kubectl apply -f ../app-repo-blueprint-argo-workflows/argo-manifests/workflow-template.yaml
```

### 2. Create Git SSH Secret

For STACKIT Git Service access:

```bash
kubectl create secret generic git-ssh-key \
  --from-file=ssh-private-key=$HOME/.ssh/id_rsa \
  -n argo
```

### 3. Access Argo Workflows UI

```bash
# Get LoadBalancer IP
kubectl get svc -n argo argo-workflows-server

# Or port-forward
kubectl port-forward -n argo svc/argo-workflows-server 2746:2746

# Open browser
open http://localhost:2746
```

## Usage

### Option 1: Manual Workflow Trigger

```bash
kubectl create -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: build-
  namespace: argo
spec:
  serviceAccountName: argo-workflow
  workflowTemplateRef:
    name: kaniko-build
  arguments:
    parameters:
      - name: repo-url
        value: "git@git.stackit.cloud:myproject/myrepo.git"
      - name: image-name
        value: "harbor.example.com/myproject/myapp"
      - name: image-tag
        value: "v1.0.0"
EOF
```

### Option 2: Automated via Git Webhooks

Deploy EventSource and Sensor (see `app-repo-blueprint-argo-workflows` for examples):

```bash
kubectl apply -f eventsource.yaml
kubectl apply -f sensor.yaml
```

Then configure STACKIT Git webhook to point to the EventSource service.

### Option 3: Via Building Block

When provisioning namespaces, enable Argo Workflows:

```hcl
inputs = {
  namespace_name        = "team-a-dev"
  enable_argo_workflows = true
  git_repo_url          = "git@git.stackit.cloud:team-a/app.git"
  image_name            = "harbor.example.com/team-a/app"
}
```

This automatically creates EventSource and Sensor for the namespace.

## Architecture

```
Git Push (STACKIT Git)
    ↓
EventSource (webhook receiver)
    ↓
Sensor (workflow trigger)
    ↓
Workflow (Kaniko build)
    ↓
Harbor Registry (image pushed)
    ↓
ArgoCD (deploys app)
```

## Configuration

### Helm Chart Versions

Default versions (can be overridden via `inputs`):

- `argo-workflows`: 0.42.5
- `argo-events`: 2.4.8

### Server Authentication

Default: `--auth-mode=server` (no authentication)

For production, enable SSO:

```hcl
inputs = {
  argo_workflows_auth_mode = "sso"
}
```

## Examples

See `app-repo-blueprint-argo-workflows/` for:

- EventSource definitions
- Sensor configurations
- WorkflowTemplate examples
- Full integration with STACKIT Git Service

## Outputs

```bash
terragrunt output namespace                  # "argo"
terragrunt output workflow_service_account   # "argo-workflow"
```

## Troubleshooting

### Workflows stuck in pending

```bash
kubectl logs -n argo -l app.kubernetes.io/name=argo-workflows-workflow-controller
```

### EventSource not receiving webhooks

```bash
kubectl get svc -n argo
kubectl logs -n argo -l eventsource-name=<name>
```

### Kaniko build fails

```bash
kubectl get workflow -n argo
kubectl logs -n argo <workflow-pod-name>
```

## Next Steps

1. Deploy WorkflowTemplate for your build process
2. Configure STACKIT Git webhooks
3. Enable in building-block for team namespaces
4. Add Slack/email notifications on build completion

## References

- [Argo Workflows Docs](https://argo-workflows.readthedocs.io)
- [Argo Events Docs](https://argoproj.github.io/argo-events)
- [Kaniko Docs](https://github.com/GoogleContainerTools/kaniko)
