# ADR-002 — Bootstrap Platform Provision & Configuration Scope

**Status:** Accepted  
**Date:** 2025-11-18 (updated 2025-11-19)

## Decision

The bootstrap of the *Sovereign Developer Platform* is split into two clearly separated layers:

- **Platform Provision Layer** – creates platform infrastructure resources.  
- **Platform Configuration Layer** – initializes and configures these resources from inside.

All app environments (app-env) build on top of the configured platform.

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

- Requires two Terraform runs for the platform (Provision → Configuration).  
- Slightly higher conceptual overhead for new contributors, who must understand the two layers.  

---

## Future Work

- Add KMS provisioning to the Provision Layer and its internal configuration to the Configuration Layer.  
- Add Argo CD setup following the same pattern (infrastructure vs. in-cluster configuration).  
- Add DNS and observability components with clear Provision/Configuration separation.  
- Introduce optional token rotation or OIDC federation for the platform ServiceAccount.  
- Document operator workflows and CI usage based on the Provision/Configuration split.

---

**Note:**  
*All Terraform code, documentation, and comments MUST be written in English.*
