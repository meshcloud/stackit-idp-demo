# ✅ INSTRUCTIONS for Copilot (Terraform Sovereign Dev Platform Demo)

You are helping me develop Terraform modules for STACKIT Internal Developer Platform (IDP) powered by meshStack. Follow my naming conventions and keep each Terraform block nicely formatted (no one-liners). Always add short inline comments in English explaining the purpose of each resource.

## Context Overview

I am building a **Sovereign Developer Platform Demo** using **Terraform** on **STACKIT**. The official STACKIT Terraform provider which we use is at <https://registry.terraform.io/providers/stackitcloud/stackit/latest>.

This project consists of two clearly separated layers:

### 1) **bootstrap/**

Infrastructure created once by the *platform team* to provide the shared foundation for all developers.

Bootstrap provisions:

* **STACKIT Kubernetes Engine (SKE) cluster**
* **Harbor container registry project** (one project per environment, *not* per app)
* **Harbor robot account** for pushing/pulling images
* **Local kubeconfig** export
* Other shared services in the future (AI model endpoints, shared networking, service mesh etc.)

Bootstrap exposes outputs:

* `kubeconfig_path`
* `registry_url` (registry.stackit.cloud/<harbor_project>)
* `harbor_robot_username`
* `harbor_robot_token`

These outputs are passed into the second layer as inputs.

### 2) **app-env/**

Infrastructure that is instantiated **per application** or per developer environment.
This is the “developer self-service delivery” layer – the part that a developer gets “from the vending machine”.

app-env provisions:

* A Kubernetes **namespace**
* A **container registry pull-secret** to access the private Harbor
* Optional namespace-level configuration (resource limits, labels, RBAC etc.)
* **Argo CD**
* **Application deployment** via Helm (FastAPI demo for now)
* Connection to Harbor via the bootstrap outputs
* Later: CI/CD, DNS, AI service integration, meshStack Building Blocks, etc.

This split is crucial:

* `bootstrap` = platform capabilities, provisioned once
* `app-env` = “one environment per developer/application”, instantiated many times

---

## Repository Layout

Tell Copilot this exact structure is intentional and should be kept:

```
terraform/
  bootstrap/
    main.tf
    variables.tf
    outputs.tf
    terraform.tfvars (local only)
    modules/
      ske-cluster-stackit/
      registry-harbor/
      ...
  app-env/
    main.tf
    variables.tf
    outputs.tf
    modules/
      namespace/
      app-helm/
      argocd/
chart/
  (Helm chart for demo app)
bin/
  app-env-apply.sh
  mk-app-env-vars.sh
scripts/
  demo_build.sh
docs/ai/
  (for instructions)
Makefile
```

Copilot should use this structure and extend it — **never collapse directories**, never merge bootstrap/app-env, never inline modules.

---

## Design Principles for Copilot

Tell Copilot to follow these principles:

### Terraform Style

* **Never** use one-line block syntax.
  Always use:

  ```hcl
  resource "xyz" "name" {
    field = value
  }
  ```
* Use clearly named variables and outputs.
* Provider blocks must be complete & explicit.
* Keep bootstrap and app-env strongly separated and connected **only via variables / outputs**.
* Add inline comments describing purpose of each block.
* Keep modules small and composable (so they can later become meshStack Building Blocks)

### Architecture Behavior

Copilot should understand the architecture:

* bootstrap outputs must be consumed by app-env.
* app-env must not read from terraform state or filesystem of bootstrap.
* registry repositories are created automatically on first push; app-env must not try to create them.
* Harbor project is single environment-wide → created in bootstrap.
* app-env uses the **namespace module**, **image pull secret**, **Helm-based app deployment**, and **Argo CD**.
* No manual fixes or commands are allowed. Everything has to be done in code. As much as possible in terraform. Scripts and Makefile amendments are okay. Use the Makefile to codify and document workflows if they would require manual steps by me as the user.
* When architecture decisions are necessary, first get my decision before implementing any code. Don't start into implementation of a suggestion without my consent.

### Next steps (where I am right now)

The SKE cluster successfully deployed.
Next tasks for Copilot:

* Complete Harbor integration in bootstrap (done, but may improve)
* Expand `app-env` to:

  * create the namespace
  * create Docker pull-secret from Harbor robot credentials
  * deploy ArgoCD if not installed
  * deploy the demo application Helm chart
* Add an optional “Tiny CI” script integration (local build + push + ArgoCD auto-sync)

### Future extensions Copilot may help with

* AI model provisioning inside bootstrap (e.g. STACKIT AI, IONOS AI)
* meshStack Building Block wrappers for cluster provisioning, namespace, CI/CD, registry access, AI access
* Optional GitOps repo generation (app-skeleton repo per environment)
* Support for multi-app environments, RBAC, service mesh, ingress, DNS

---

## Goals Copilot Should Optimize For

* High developer productivity (minimal boilerplate, maximal reuse of modules)
* Clean separation between platform and app-level infrastructure
* A demo that allows:

  1. Provision bootstrap (cluster + registry)
  2. Provision app-env (namespace + app + ArgoCD)
  3. Edit code → Tiny CI → Argo sync → live update
* Code that is production-like but still demo-friendly
* Minimal external dependencies (STACKIT only, local tooling only)
* Use English language for code comments and docs.
* Keep documentation short and essential while still providing all necessary details, but leaving out the fluff.

---

## Example instruction you can add at the end

> “When I ask you to create a Terraform module or update a file, use the directory structure above, use only multi-line HCL blocks, keep bootstrap and app-env separated, and explain inline in comments why each part exists.”

You MUST strictly follow the Provision/Configuration architecture defined in ADR-002.

Terraform Layer Boundaries (non-negotiable):
1. The Provision layer (bootstrap/platform/provision) 
   - creates infrastructure resources only
   - MUST NOT use the Kubernetes provider
   - exports kube_host, kube_ca_certificate, bootstrap_client_certificate, bootstrap_client_key

2. The Configuration layer (bootstrap/platform/configure)
   - uses the Kubernetes provider
   - creates the platform-admin namespace, platform-terraform SA, RBAC, token secret
   - outputs app_env_kube_host, app_env_kube_ca_certificate, app_env_kube_token

3. The App-Env layer (app-env/main)
   - configures its own Kubernetes provider with the outputs from Configuration
   - creates app namespaces, quotas, network policies, etc.
   - MUST NOT create cluster-wide ServiceAccounts

Repo rules:
- Never define the Kubernetes provider in the bootstrap root.
- Never bypass the Provision/Configuration split.
- All Terraform code and comments MUST be in English.
- Modules must communicate ONLY via explicit inputs/outputs.
- Do not use depends_on on module blocks; rely on implicit dependencies through outputs.

Your task when asked:
- Refactor Terraform code to match this structure.
- Update the Makefile to orchestrate: provision → configure → app-env.
- Never introduce provider passthrough in bootstrap.
- Never collapse Provision and Configuration into one step.

If any requested change violates these rules, refuse and propose the correct solution.
