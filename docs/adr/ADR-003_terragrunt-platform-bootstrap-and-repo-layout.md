# ADR-003: Terragrunt-based platform bootstrap and repository layout

- **Status:** Accepted  
- **Date:** 2025-12-09  
- **Supersedes:** ADR-002

---

## Context

The Sovereign Developer Platform (STACKIT IDP Demo) was initially designed with a three-step bootstrap approach: Provision, Configure, and App-Env layers, as documented in ADR-002. As the platform evolved, we reorganized the infrastructure-as-code to adopt **Terragrunt** for orchestration and introduced a **numbered layer structure** to make dependencies explicit and enable incremental deployment.

The previous ADR-002 described the conceptual bootstrap model but did not account for:

- The evolution from simple Terraform modules to a Terragrunt-managed multi-layer setup
- The introduction of reusable building blocks for app team environments
- The need for a clearer, more operationally maintainable repository layout

This ADR documents the current Terragrunt-based platform architecture and repository organization.

---

## Decision

The platform uses a **Terragrunt-orchestrated, numbered-layer bootstrap** with a `platform/` directory structured as follows:

### Numbered Layers (Sequential Dependencies)

Each numbered directory under `platform/` represents a deployment layer with explicit dependencies:

1. **`00-state-bucket/`** — Provisions the remote state bucket for all subsequent layers.
   - Creates an S3-compatible object storage bucket in STACKIT.
   - Output: S3 endpoint and credentials for Terragrunt remote state.

2. **`01-ske/`** — Provisions the Kubernetes cluster (SKE).
   - Creates the STACKIT SKE cluster with default node pools and configuration.
   - Exports: `kube_host`, `cluster_ca_certificate`, kubeconfig path.

3. **`02-meshstack/`** — Integrates meshStack into the cluster.
   - Deploys meshStack platform and self-service portal components into the provisioned cluster.
   - Establishes the meshStack control plane.

4. **`03-argocd/`** — Deploys and configures ArgoCD.
   - Installs ArgoCD into the cluster for GitOps-driven deployments.
   - Sets up initial repository connections and app templates.

5. **`04-argo-workflows/`** — Deploys Argo Workflows tooling.
   - Installs Argo Workflows for workflow automation and CI/CD orchestration.

### Terragrunt Orchestration

- Each layer is a Terragrunt module that includes the root configuration (`root.hcl`).
- Remote state is centrally configured in `root.hcl` to use the S3-compatible STACKIT Object Storage.
- Dependencies between layers are enforced by:
  - Explicit layer numbering (layers deploy in order).
  - Terragrunt's remote state backend: later layers read outputs from earlier layers via data sources.
  - Layer-specific input variables set in each layer's `terragrunt.hcl`.

### Reusable Building Blocks (`platform/building-blocks/`)

Under `platform/building-blocks/`, we maintain reusable Terraform modules designed as **meshStack Building Blocks**. These are used to provision resources for app teams:

- **`namespace-with-argocd/`** — Creates an application namespace with ArgoCD configuration, network policies, resource quotas, and namespace-level RBAC. Maps to a meshStack Building Block for app team onboarding.
- **`stackit-git-repo/`** — Provisions a Gitea repository within the STACKIT Git Service for an application. Enables teams to push source code and track app configurations.

These building blocks are:

- Parameterized and reusable across multiple app teams.
- Able to be invoked independently or as part of a meshStack workspace definition.
- Encapsulate best practices (network policies, resource quotas, RBAC) for app team security and isolation.

---

## Rationale

### Why Terragrunt?

1. **Dependency Management:** Numbered layers make deployment order explicit and prevent circular dependencies.
2. **State Isolation:** Each layer maintains its own Terraform state file with a clear path in remote storage.
3. **DRY Principle:** Common configuration (provider, remote state, variables) is centralized in `root.hcl` and inherited by all layers.
4. **Operational Clarity:** Clear layer structure makes it obvious what can be deployed independently and what has dependencies.

### Why Numbered Layers?

1. **Sequential Clarity:** Layer numbers immediately communicate deployment order: `00` before `01` before `02`, etc.
2. **Room for Growth:** Numbering allows insertion of new layers without restructuring (e.g., `02b-` for sub-layers if needed in the future).
3. **Reduced Ambiguity:** Alternatives (stage names like `provision/configure/deploy`) risk name conflicts or unclear boundaries.

### Why Building Blocks?

1. **Alignment with meshStack:** Building Blocks are the native meshStack concept for reusable, team-facing infrastructure components. Our Terraform modules are designed to map directly to meshStack Building Blocks in the future.
2. **Reproducibility:** App teams provision identical, secure resources through a single, tested module rather than ad-hoc configuration.
3. **Standardization:** Building blocks enforce security and resource policies (network policies, quotas, RBAC) consistently across all namespaces.

### Relationship to ADR-002

ADR-002 established the conceptual Provision/Configuration/App-Env model, which remains valid at a high level:

- **Numbered layers 00–04** collectively implement the **Provision** phase (platform infrastructure setup).
- **Building blocks** enable the **Configuration** phase (preparation for app teams) and the **App-Env** phase (individual app team provisioning).

However, ADR-002 described a simpler two-phase (Provision → Configure) pattern with manual state injection scripts. This ADR supersedes that with a more granular approach:

- A more granular layered approach using Terragrunt.
- Explicit remote state management instead of local state injection.
- Building blocks as a scalable foundation for app team onboarding.

---

## Consequences

### Positive Consequences

1. **Clear Layering and Dependencies:** Numbered layers make the deployment sequence unmistakable, reducing confusion and enabling parallel work.

2. **Repeatable Infrastructure Deployments:** Terragrunt's centralized remote state ensures all deployments are reproducible, auditable, and recoverable.

3. **Scalable App Team Provisioning:** Building blocks provide a standardized, reusable pattern for on-boarding teams, avoiding duplication and configuration drift.

4. **meshStack-Ready Architecture:** The building block design aligns perfectly with meshStack's native provisioning model, enabling a smooth future migration from manual Terragrunt orchestration to meshStack-driven automation.

5. **Better Separation of Concerns:** Platform engineers manage layers; app teams interact with building blocks. Clear boundaries reduce cross-team friction.

6. **Incremental Deployment:** Each layer is independent enough to be redeployed or debugged in isolation, speeding up development and troubleshooting.

### Negative Consequences / Risks

1. **Increased Complexity:** Terragrunt introduces another abstraction layer on top of Terraform. New contributors must understand:
   - How Terragrunt includes and merges configuration.
   - How remote state paths are computed.
   - How layers interact via remote state outputs.

2. **Debugging Overhead:** Terragrunt's code generation (e.g., `backend.tf`) can obscure the actual Terraform configuration. Errors may be harder to trace.

3. **Tight Coupling via Remote State:** Layers depend on other layers' remote state. If a layer's state is corrupted or manually edited, downstream layers may fail unexpectedly. Requires careful state management practices.

4. **Documentation Burden:** The layered structure and building block design must be well-documented and kept in sync with actual code. Drift between docs and implementation will confuse operators.

5. **Migration from ADR-002:** Existing documentation and scripts based on ADR-002's three-step model (Provision/Configure/App-Env with state injection) are now outdated. Operators familiar with that approach must re-learn the new structure.

6. **Limited Provider Flexibility:** All layers must use consistent provider versions and configurations. Layer-specific provider customization is more complex under Terragrunt.

---

## Open Questions & Future Work

1. **Layer 05+:** As the platform evolves, should we add layers for:
   - Secret management (KMS, Sealed Secrets)?
   - Observability and monitoring (Prometheus, Grafana)?
   - Additional cluster capabilities (Ingress Controller, CSI drivers)?
   - Should these be separate layers or bundled into existing layers?

2. **State Backup and Recovery:** How do we handle Terragrunt remote state backups and disaster recovery?

3. **Local Development:** How do contributors run layers locally without polluting the shared remote state? Should we support local backend modes for dev/test?

4. **Multi-Environment Support:** How do we adapt this layout for multiple environments (dev, staging, production)?

5. **Building Block Versioning:** As building blocks evolve, how do we manage versions and compatibility across app teams?

6. **Automation and Operators:** Should we implement Kubernetes operators or webhooks to automate building block provisioning based on meshStack workspaces?

---

## Next Steps

1. Update all platform documentation to reference this ADR and Terragrunt-based structure.
2. Mark ADR-002 as superseded and archive for historical reference.
3. Create operator runbooks for:
   - Deploying layers in sequence.
   - Troubleshooting layer failures.
   - Recovering from state corruption.
4. Establish naming and parameterization conventions for future building blocks.
5. Plan integration with meshStack platform for automatic Building Block provisioning.

---

**Note:**  
*All Terraform code, documentation, and comments MUST be written in English.*
