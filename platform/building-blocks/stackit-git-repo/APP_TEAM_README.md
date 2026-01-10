# STACKIT Git Repository

## What is it?

The **STACKIT Git Repository** building block automatically creates a Git repository on STACKIT Git (Forgejo/Gitea) with pre-configured CI/CD integration. It can create repositories from templates, set up deploy keys, and configure webhooks for automatic builds.

## When to use it?

This building block is ideal for teams that:

- Need a Git repository on STACKIT Git infrastructure
- Want to start from a pre-configured application template (e.g., Python, Node.js)
- Need automatic CI/CD integration via webhooks
- Require secure repository access via deploy keys

## Usage Examples

1. **Starting a new application**: Use this building block to create a repository from a template (e.g., `app-template-python`) with pre-configured Dockerfile and local build scripts.

## Resources Created

This building block automates the creation of the following resources:

- **Git Repository**: A new repository in STACKIT Git (Forgejo/Gitea)
  - Can be created from a template with variable substitution
  - Configured as private or public
  - Auto-initialized with README
- **Webhook** (optional): Triggers CI/CD pipeline on code push
- **Deploy Key** (optional): SSH key for secure repository access

## Shared Responsibilities

| Responsibility                               | Platform Team | Application Team |
| -------------------------------------------- | ------------- | ---------------- |
| Provision STACKIT Git infrastructure         | ✅            | ❌               |
| Create and configure Git repository          | ✅            | ❌               |
| Set up webhooks for CI/CD integration        | ✅            | ❌               |
| Configure deploy keys                        | ✅            | ❌               |
| Manage STACKIT Git API tokens                | ✅            | ❌               |
| Develop and maintain application source code | ❌            | ✅               |
| Commit and push code changes                 | ❌            | ✅               |
| Manage branches and pull requests            | ❌            | ✅               |
| Review and merge code                        | ❌            | ✅               |

---

## How to Use Your Repository

Your repository is automatically created and configured. To start working:

### 1. Clone Your Repository

```bash
git clone https://git-service.git.onstackit.cloud/<your-org>/<your-repo>.git
cd <your-repo>
```

### 2. Repository Structure (if created from template)

```
your-repo/
├── app/                           # Application code
│   ├── Dockerfile                 # Container build instructions
│   ├── requirements.txt           # Dependencies
│   └── main.py                    # Application code
└── manifests/
    └── base/                      # Kubernetes manifests
        ├── kustomization.yaml
        ├── deployment.yaml
        └── service.yaml
```

### 3. Make Changes and Push

```bash
# Make your changes
git add .
git commit -m "Your change description"
git push
```

### 4. Automatic Build Triggered

If webhooks are configured, pushing code will automatically:
- Trigger a build in Argo Workflows
- Build a container image
- Push to Harbor registry
- Deploy via ArgoCD

## Getting Help

- Access your repository: https://git-service.git.onstackit.cloud
- Contact platform team for infrastructure issues
- Check Argo Workflows UI for build status
