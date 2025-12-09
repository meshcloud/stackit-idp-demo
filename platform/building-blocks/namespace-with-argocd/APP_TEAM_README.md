# STACKIT Kubernetes Namespace with GitOps

## What is it?

The **STACKIT Kubernetes Namespace with GitOps** building block provides application teams with a pre-configured Kubernetes environment following the organization's best practices. It automates the creation of essential infrastructure, including a Git repository, a CI/CD pipeline using Argo Workflows, and ArgoCD-based GitOps deployments with Harbor container registry integration.

## When to use it?

This building block is ideal for teams that:

- Want to deploy applications on Kubernetes without worrying about setting up infrastructure from scratch.
- Need a secure, best-practice-aligned environment for developing, testing, and deploying workloads.
- Prefer a streamlined CI/CD setup with built-in security and GitOps automation.

## Usage Examples

1. **Deploying a microservice**: A developer can use this building block to create a Git repository and CI/CD pipeline for a new microservice. The pipeline will build container images tagged with git commit SHAs and automatically deploy them into Kubernetes namespaces.
2. **Setting up a new project**: A new project team can quickly get started with an opinionated STACKIT Kubernetes setup that ensures compliance with the organization's security and operational standards.

## Resources Created

This building block automates the creation of the following resources:

- **Git Repository**: A repository in Gitea to store your application code and Dockerfile.
- **Kubernetes Namespace**: A dedicated namespace in the STACKIT Kubernetes Engine cluster.
  - **Argo Workflows Pipeline**: Automatically builds container images on every commit and pushes them to Harbor registry.
  - **ArgoCD Application**: Monitors Harbor for new images and automatically deploys updates to your namespace.
  - **Harbor Robot Account**: Credentials for pushing and pulling container images.

## Shared Responsibilities

| Responsibility                               | Platform Team | Application Team |
| -------------------------------------------- | ------------- | ---------------- |
| Provision and manage Kubernetes cluster      | ✅            | ❌               |
| Create and manage Git repository             | ✅            | ❌               |
| Set up Argo Workflows CI pipeline            | ✅            | ❌               |
| Set up ArgoCD GitOps deployment              | ✅            | ❌               |
| Build and push container images              | ✅            | ❌               |
| Manage Kubernetes namespaces                 | ✅            | ❌               |
| Manage Harbor container registry             | ✅            | ❌               |
| Manage resources inside namespaces           | ❌            | ✅               |
| Develop and maintain application source code | ❌            | ✅               |
| Maintain Dockerfile and dependencies         | ❌            | ✅               |
| Maintain Kubernetes manifests                | ❌            | ✅               |
| Push commits to trigger deployments          | ❌            | ✅               |

---

## How It Works

When you push code to your Git repository:

1. **Automatic Build** - Argo Workflows automatically builds a container image tagged with the git commit SHA and pushes it to Harbor registry
2. **Automatic Deployment** - ArgoCD detects the new image in Harbor (checks every ~2 minutes) and updates your deployment

Your application is always tagged with the git commit SHA (e.g., `609f95f`) so you can track exactly which version is deployed.

## Repository Structure

Your repository should contain:

```
your-app/
├── app/                           # Application code
│   ├── Dockerfile                 # Container build instructions
│   ├── requirements.txt           # Dependencies (Python example)
│   └── main.py                    # Application code
└── manifests/
    └── base/                      # Kubernetes manifests
        ├── kustomization.yaml
        ├── deployment.yaml
        └── service.yaml
```

## Deploying Changes

1. **Make your changes** to application code or manifests
2. **Commit and push** to your repository:
   ```bash
   git add .
   git commit -m "your change description"
   git push
   ```
3. **Wait 1-2 minutes** - your application will automatically build and deploy

## Checking Deployment Status

### View Build Progress
Access Argo Workflows UI to see build logs:
- Build workflow runs automatically on each push
- Check logs if build fails

### View Deployment Status
Access ArgoCD UI to see deployment status:
- Shows current deployed version (git SHA)
- Shows sync status and health
- Shows deployment history

