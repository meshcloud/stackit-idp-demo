# ADR-002 — Bootstrap Platform Provision & Configuration Scope

- **Status:** Superseded
- **Date:** 2025-11-18 (finalized 2025-11-27, superseded 2025-12-09)
- **Superseded by**: ADR-003

> Note: This ADR describes an early bootstrap concept (three-step model).  
> It has been superseded by ADR-003, which documents the Terragrunt-based platform bootstrap and repo layout.

## Decision

The bootstrap of the *Sovereign Developer Platform* is split into two clearly separated layers:

- **Platform Provision Layer** – creates platform infrastructure resources.  
- **Platform Configuration Layer** – initializes and configures these resources from inside.

All app environments (app-env) build on top of the configured platform.

Credentials and state flow through explicit state injection (Python scripts and Makefile orchestration), enabling deterministic Terraform execution and long-lived automation identities.

---

## A. Platform Components Provisioned by Bootstrap

The following components are considered *platform-level* and are provisioned exactly once in the **Provision Layer**. They are shared by all application environments:

1. **SKE Kubernetes Cluster** — *required*  
2. **Harbor Registry** — *required (as defined in ADR-001)*  
3. **Secret Store (KMS)** — *planned, not yet implemented*  
4. **Argo CD** — *planned, not yet implemented*  
5. **Cluster Observability/Monitoring** — *planned, not yet implemented*  
6. **DNS Zone and DNS Management** — *planned, not yet implemented*

These components form the **platform foundation** for all app-envs.

---

## B. Platform Provision Layer (`bootstrap/platform/provision`)

The **Provision Layer** creates platform-wide infrastructure resources but does **not** use any in-cluster providers such as the Kubernetes provider.

Responsibilities:

- Create the STACKIT SKE Kubernetes cluster.  
- Create Harbor and future platform-level components (KMS, Argo CD, monitoring, DNS) as they are added.  
- Export all information required to connect to the cluster and other components, for example:
  - `kube_host`  
  - `cluster_ca_certificate`  
  - `bootstrap_client_certificate` (client certificate for admin access, base64-encoded)
  - `bootstrap_client_key` (client key for admin access, base64-encoded)

**Constraints:**

- The Terraform **Kubernetes provider must not be initialized** in this layer.  
- This avoids dependency cycles, provider oscillation, and race conditions during cluster creation.  
- This layer interacts only with cloud control plane APIs (e.g. STACKIT providers), not with in-cluster APIs.

---

## C. Platform Configuration Layer (`bootstrap/platform/configure`)

The **Configuration Layer** runs only after the Provision Layer has successfully completed. It connects to the already provisioned platform components and performs the **one-time platform initialization inside** these systems.

For Kubernetes, this includes:

- Creating namespace `platform-admin`.  
- Creating ServiceAccount `platform-terraform`.  
- Creating minimal RBAC (ClusterRole + ClusterRoleBinding) that allows:
  - namespace creation/deletion  
  - management of `ResourceQuota`, `LimitRange`, `NetworkPolicy`  
  - management of `RoleBinding` and `ClusterRoleBinding`  
  - management of `Secret` and `ConfigMap`  
- Creating a ServiceAccount token and reading it from a token Secret.

**Outputs of the Configuration Layer (consumed by app-env):**

- `app_env_kube_host`  
- `app_env_kube_ca_certificate`  
- `app_env_kube_token` (the `platform-terraform` ServiceAccount token)

This token represents the **platform-level automation identity**, reused by all app-env modules.

The same pattern can be applied to other systems in the future:

- Databases: provision instance in Provision, create schemas/users in Configuration.  
- Secret stores: provision instance in Provision, configure engines/policies in Configuration.  
- Argo CD, DNS, Observability: similarly split into infrastructure vs. internal configuration.

---

## D. App-Env Layer Consumption

Each app environment (app-env) uses only the outputs from the **Platform Configuration Layer**.

For Kubernetes, app-env:

- Configures its own Kubernetes provider with:  
  `host + ca + token` from the platform Configuration Layer.  
- Creates:
  - its application namespace(s)  
  - resource quotas and limit ranges  
  - default-deny network policies  
  - environment-specific RBAC and other app-level resources

**Important:**

- App-env **never creates cluster-wide ServiceAccounts**.  
- App-env builds strictly on top of the single platform ServiceAccount created in the Configuration Layer.

---

## Rationale

- **Clear separation of concerns**:  
  - Provision Layer: “The platform exists.”  
  - Configuration Layer: “The platform is initialized and ready for app-envs.”
- **Deterministic Terraform execution**:  
  - No provider initialization while resources are being created.  
  - Fewer race conditions and no “oscillating” plans.
- **meshStack-ready architecture**:  
  - Provision and Configuration map naturally to platform Building Blocks.  
  - App-env blocks consume typed outputs only, without hidden coupling.
- **Operational simplicity**:  
  - Exactly one long-lived platform automation identity.  
  - App-env logic can evolve independently without touching platform bootstrap.
- **Extensibility**:  
  - The same Provision/Configuration pattern can be reused for databases, secret stores, Argo CD, DNS, observability, etc.

---

## Consequences

**Pros**

- Strong modularity and clean architecture boundaries.  
- Reliable Terraform runs, fewer surprises.  
- Smooth migration from local Makefile-driven orchestration to meshStack Building Blocks.  
- Easier auditing and long-term maintenance.  
- Reduces complexity at the app-env level: platform concerns stay in platform code.

**Cons**

- Requires two Terraform runs for the bootstrap platform (Provision → Configuration).  
- Slightly higher conceptual overhead for new contributors, who must understand the two layers and state injection pattern.  
- State injection scripts must be maintained alongside Terraform code.

---

## E. State Injection Pattern (Implementation Detail)

Layers communicate through **explicit state injection** via Python scripts invoked by the Makefile:

### Provision → Configure

Script: `scripts/inject-provision-to-configure.py`

```bash
make configure  # Internally runs:
  1. Check Provision state exists
  2. python3 scripts/inject-provision-to-configure.py
     - Reads: terraform/bootstrap/platform/provision/terraform.tfstate
     - Extracts: kube_host, cluster_ca_certificate, bootstrap_client_certificate, bootstrap_client_key
     - Writes: terraform/bootstrap/platform/configure/terraform.auto.tfvars.json
  3. terraform apply in Configure layer
```

**Why this pattern?**
- Explicit, auditable credential flow
- No tight coupling via remote state
- Layer independence and modularity
- Easy to debug and understand
- Hybrid fallback: Direct variable input also supported

### Configure → App-Env

Script: `scripts/inject-configure-to-appenv.py`

```bash
make app-env  # Internally runs:
  1. Check Configure state exists
  2. python3 scripts/inject-configure-to-appenv.py
     - Reads: terraform/bootstrap/platform/configure/terraform.tfstate
     - Extracts: app_env_kube_host, app_env_kube_ca_certificate, app_env_kube_token
     - Writes: terraform/app-env/terraform.auto.tfvars.json
  3. terraform apply in App-Env layer
```

**Key difference from Provision → Configure:**
- Configure layer extracts **long-lived token** (from platform-terraform ServiceAccount Secret)
- This token persists indefinitely and is used for all future App-Env deployments
- No dependency on short-lived Provision kubeconfig

---

## F. Long-Lived Token Strategy & Testing

### Token Lifecycle

| Phase | Credential | Lifespan | Purpose |
|-------|-----------|----------|---------|
| Provision | SKE kubeconfig (Client-Cert) | ~8h | Certificate-based auth for Configure layer |
| Configure | platform-terraform token | Indefinite | Token-based auth for App-Env layer |
| App-Env | Same platform-terraform token | Indefinite | Persistent automation identity |

### Testing & Manual Access

**Automated Testing:**

```bash
make test-connection
```

Runs automated checks:
- Cluster connectivity (kubectl cluster-info)
- Namespace existence (kubectl get ns demo-app)
- ResourceQuota configuration
- NetworkPolicy configuration

**Manual Testing:**

```bash
make kubeconfig              # Generate kubeconfig with long-lived token
export KUBECONFIG=/tmp/kubeconfig-token
kubectl get ns demo-app      # Use kubectl with persistent credentials
```

**Why this matters:**
- Original kubeconfig expires after ~8h
- Token-based kubeconfig persists indefinitely
- Enables reliable testing and manual operations
- Foundation for CI/CD integration

---

## G. Makefile Orchestration

The Makefile provides high-level targets that coordinate the three layers:

```bash
make validate      # Validate all layers
make provision     # Deploy Provision layer (Phase A)
make configure     # Inject + Deploy Configure layer (Phase B)
make app-env       # Inject + Deploy App-Env layer (Phase C)
make test-connection  # Verify deployment with automated tests
make kubeconfig    # Generate persistent kubeconfig for manual access
make down          # Destroy all layers (reverse order)
```

Each target encapsulates layer dependencies and state injection logic, simplifying operations and reducing manual error.

---

## Future Work

- **ADR-003:** Token rotation strategy (automatic vs. manual, Kubernetes CronJob, Secrets Manager integration)
- **ADR-004:** Argo CD setup following the same Provision/Configuration pattern  
- **ADR-005:** KMS and Secret Store provisioning and configuration  
- **ADR-006:** DNS and Observability/Monitoring components with clear layer separation  
- **ADR-007:** OIDC federation for platform-terraform ServiceAccount  
- **CI/CD Integration:** Operator workflows for automated deployment and token management  
- **Multi-Cluster Support:** Extend state injection pattern to manage multiple clusters  
- **meshStack Integration:** Migrate from Makefile orchestration to Building Blocks (mapped to Provision/Configuration/App-Env layers)

---

**Note:**  
*All Terraform code, documentation, and comments MUST be written in English.*
