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

## How Deployment Works

1. Push code to `main` branch
2. GitHub Actions builds image and pushes to Harbor
3. GitHub Actions updates manifest with new image tag and commits
4. ArgoCD detects manifest change and syncs to cluster
5. Kubernetes performs rolling update

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

## Support

Contact platform team or check platform documentation.
