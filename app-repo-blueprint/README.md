# App Team Repository Blueprint

This is a template repository for application teams using the STACKIT IDP platform.

## Structure

```
.
├── app/                    # Application code
│   ├── main.py            # FastAPI application
│   ├── requirements.txt   # Python dependencies
│   └── Dockerfile         # Container image definition
├── manifests/             # Kubernetes manifests
│   ├── base/              # Base Kustomize configuration
│   └── overlays/          # Environment-specific overlays
│       ├── dev/
│       └── prod/
└── .github/workflows/     # CI/CD pipelines
    └── build-push.yaml    # Build and push to Harbor
```

## Getting Started

### Prerequisites

- Access to STACKIT SKE cluster
- Harbor registry credentials
- GitHub repository

### 1. Request Namespace via meshStack

Order a namespace through the meshStack portal. This will automatically:
- Create your Kubernetes namespace
- Set up Harbor project and pull secrets
- Deploy ArgoCD Application pointing to this repo

### 2. Clone and Customize

```bash
git clone https://github.com/your-org/your-app
cd your-app
```

Edit `app/main.py` with your application logic.

### 3. Configure CI/CD

Set GitHub repository secrets:
- `HARBOR_PROJECT`: Your Harbor project name (provided by platform team)
- `HARBOR_USERNAME`: Your robot account username (provided by platform team)
- `HARBOR_PASSWORD`: Your robot account token (provided by platform team)

### 4. Push Changes

```bash
git add .
git commit -m "Initial commit"
git push origin main
```

## How Deployment Works (GitOps with ArgoCD)

The deployment follows the recommended ArgoCD pattern:

1. **Developer pushes code** to `main` branch
2. **GitHub Actions triggers** and:
   - Builds Docker image
   - Tags with Git SHA (e.g., `main-abc123`)
   - Pushes to Harbor registry
   - **Updates `manifests/base/kustomization.yaml`** with new image tag
   - **Commits and pushes** manifest change to Git
3. **ArgoCD detects Git change** (via webhook or polling)
4. **ArgoCD syncs** the new manifest to your namespace
5. **Kubernetes performs rolling update** with new image

### Why This Works

- ✅ **Git is source of truth**: Exact image version is tracked in Git
- ✅ **Automatic deployment**: Push code → auto-deployed
- ✅ **Easy rollback**: `git revert` to rollback deployment
- ✅ **Audit trail**: All deployments visible in Git history
- ✅ **No manual steps**: Fully automated GitOps workflow

## Development

### Local Development

```bash
cd app
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

Visit http://localhost:8000

### Update Kubernetes Manifests

Edit manifests in `manifests/overlays/dev/` or `manifests/overlays/prod/`

ArgoCD monitors these files and auto-syncs to your namespace.

## Architecture

```
Developer pushes code
    ↓
GitHub Actions CI/CD Pipeline:
  1. Build Docker image
  2. Push to Harbor (registry.onstackit.cloud)
  3. Update manifests/base/kustomization.yaml (newTag: main-<sha>)
  4. Commit & push manifest change
    ↓
Git repository updated
    ↓
ArgoCD detects Git change (webhook/polling)
    ↓
ArgoCD syncs manifests to SKE namespace
    ↓
Kubernetes rolling update
    ↓
Pods pull new image from Harbor
    ✓ Deployed
```

### GitOps Flow Benefits

- **Declarative**: Desired state in Git
- **Automated**: No manual kubectl commands
- **Auditable**: Git history shows all deployments
- **Reversible**: Git revert to rollback

## Support

Contact platform team or check platform documentation.
