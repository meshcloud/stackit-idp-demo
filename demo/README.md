# Sovereign Developer Platform Demo – STACKIT + Terraform

This repository demonstrates how to build a **sovereign developer platform** on **STACKIT** using **Terraform** and **Kubernetes (SKE)**.  
It showcases how infrastructure building blocks can be combined into an automated, AI-ready developer environment — deployable in minutes and fully under your control.

---

## 🧱 Repository structure

```

terraform/
├── bootstrap/      # Base infrastructure: SKE cluster, Harbor registry project, kubeconfig export
└── app-env/        # Developer environment: namespace, Argo CD, demo app (Helm)
bin/                # Helper scripts linking the stacks (handover via TF_VAR or JSON)
chart/              # Helm chart for the demo application
Makefile            # One-command automation for setup and teardown

````

---

## ⚙️ Prerequisites

- **Terraform ≥ 1.8** – the IaC engine used for provisioning  
- **Docker** – required for building and pushing container images  
- **STACKIT access** – with a valid **service account key (JSON)** for authentication  
- Optional: **Harbor credentials** if you want Terraform to create registry projects automatically  

---

## 🚀 Usage workflow

### 1️⃣ Bootstrap the base infrastructure
```bash
make bootstrap
````

➡️ This command runs `terraform apply` inside `terraform/bootstrap/`.
It provisions the **STACKIT Kubernetes Engine (SKE)** cluster, configures a **Harbor container registry project** for storing images, and exports a local **kubeconfig** file.
After this step, you have a ready-to-use Kubernetes cluster and a private registry.

---

### 2️⃣ Deploy the application environment

**Option A – via TF_VAR wrapper**

```bash
make app-env
```

➡️ Executes the helper script `bin/app-env-apply.sh`.
This script reads all necessary outputs (cluster config, registry URL, credentials) from the bootstrap stack and passes them automatically as environment variables to `terraform/app-env`.
Result: a new **namespace**, an optional **registry pull secret**, and **Argo CD + demo app** deployed.

**Option B – via JSON handover**

```bash
make app-env-vars
```

➡️ Runs `bin/mk-app-env-vars.sh`, which generates a `handover.auto.tfvars.json` file containing all input parameters from the bootstrap phase.
When you run `terraform apply`, this file is picked up automatically and ensures a clean, file-based input contract between the stacks.

---

### 3️⃣ Verify the running application

```bash
kubectl -n demo-app port-forward svc/hello-world 8080:80
# → Open http://localhost:8080 in your browser
```

➡️ Establishes a local tunnel to the deployed demo app service inside the `demo-app` namespace.
You can now see the container running inside your STACKIT cluster.

---

### 4️⃣ Build and deploy a new version (Tiny CI)

```bash
./scripts/demo_build.sh
```

➡️ This local “Tiny CI” script simulates a CI/CD pipeline:

1. Builds a new Docker image of the demo app.
2. Pushes it to the Harbor registry.
3. Updates the image tag in the Helm `values.yaml`.
4. Commits and pushes the change to Git.
   Once committed, **Argo CD** automatically detects the change and redeploys the updated version in your cluster.

---

## 🔄 Stack decoupling

Each Terraform stack is **independent** and communicates only through well-defined interfaces:

| Stack        | Purpose                                                | Provides / Consumes                         |
| ------------ | ------------------------------------------------------ | ------------------------------------------- |
| `bootstrap/` | Sets up infrastructure: cluster, registry, credentials | Provides outputs (URLs, tokens, kubeconfig) |
| `app-env/`   | Deploys workloads and developer environment            | Consumes those outputs as inputs            |

Two supported handover mechanisms:

1. **Environment variables (TF_VAR_*)** — dynamic, simple for automation.
2. **JSON handover file (`handover.auto.tfvars.json`)** — static, explicit input contract for pipelines or sharing between teams.

This separation ensures that each stack can be maintained, versioned, or reused independently (e.g., in a CI pipeline or a partner setup).

---

## 🧹 Cleanup

To destroy the deployed resources, use:

```bash
make destroy-app-env
make destroy-bootstrap
```

➡️ These targets execute `terraform destroy` in each stack directory, removing all resources created by the demo.
Always destroy the **app environment first**, then the **bootstrap infrastructure**, to avoid dependency issues (e.g., the cluster being deleted before the app).

---

## 🧠 Purpose of the demo

This demo serves as a foundation for **webinars, partner enablement, and proof-of-concept workshops** on sovereign cloud development.
It illustrates how platform teams can:

* Provision a **STACKIT-based developer environment** automatically.
* Enable **self-service for developers** with built-in compliance and control.
* Demonstrate **AI-ready cloud-native workflows** without vendor lock-in.

> ⚡️ *Goal: From zero to a fully running, sovereign, AI-enabled developer platform in under 20 minutes – entirely hosted on European cloud infrastructure.*

