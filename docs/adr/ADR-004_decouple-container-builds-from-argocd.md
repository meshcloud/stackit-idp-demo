# ADR-004: Decouple Container Builds from Cluster Deployments via Registry-Driven GitOps

## Status

Proposed (target: Accepted)

---

## Context

We are building an enterprise-grade, opinionated Internal Developer Platform (IDP) on a European cloud provider (STACKIT). The platform prioritizes:

* excellent Developer Experience (DX)
* a clear Shared Responsibility Model (SRM)
* GitOps-based deployments with auditable state
* strict isolation between application teams
* modular, self-service delivery via meshStack Building Blocks

Historically (and in early prototypes), container image builds were executed inside the Kubernetes cluster (e.g., via Argo Workflows). This caused:

* slow feedback cycles and poor developer debuggability
* coupling build reliability to cluster availability
* higher operational and security complexity inside the cluster
* unclear responsibility boundaries between app teams and platform teams

A purely Git-driven GitOps model where application teams directly modify the GitOps state repository can be enterprise-secure, but it introduces significant governance overhead and reduces DX, especially at scale.

We need a model that:

* moves builds fully out of the cluster
* keeps Git as the single deployment source of truth
* does not require application teams to operate GitOps
* still allows application teams to influence key runtime parameters (replicas/resources/ingress) through a safe, opinionated contract

---

## Decision

### Core Principle

**Application teams never deploy to Kubernetes directly.**
They only deliver container images to an approved registry location.

**The platform is solely responsible for turning container images into running workloads, via GitOps.**

### Release Trigger (for v1 / demo)

For the initial platform blueprint (v1), **image releases are promoted via a controlled interface** (meshStack Building Block),
not via direct Git writes by application teams and not via registry-driven automation.

**The platform-owned "app-env-config" Building Block** is the only supported mechanism to update the desired release reference
for an application environment in the GitOps State Repository.

---

## Architecture Overview

The platform provides these components:

1. **Kubernetes Cluster (SKE)**

   * Provides runtime compute and isolation primitives (namespaces).

2. **ArgoCD (platform deployment engine)**

   * Continuously reconciles desired deployment state from Git into Kubernetes.
   * Deploys only prebuilt container images.

3. **GitOps State Repository (platform-owned)**

   * Contains the desired state for all application environments (app-envs).
   * Is read by ArgoCD and written only by platform automation.

4. **app-env-config Building Block (platform-controlled, mandatory for v1)**

   * Runs as a meshStack Building Block execution (Terraform runner).
   * Updates GitOps state (at minimum `release.yaml`, optionally parts of `app-env.yaml`) for a given app environment.
   * Does not deploy directly to Kubernetes; ArgoCD remains the only deployment engine.

Optional components:

* **Argo Workflows** is not part of the application delivery path.

---

## Deployment Configuration Contract (Golden Path)

Each application environment is described in the GitOps State Repository by two files:

1. **`app-env.yaml`** (platform contract, human-readable)

* Defines environment-level runtime configuration the app team can change:

  * scaling settings (replicas and/or autoscaling parameters)
  * resource requests/limits
  * ingress exposure (hostnames, paths)
  * wiring to meshStack Building Blocks (environment variables and secrets)
  * registry mapping (which registry repository this env tracks)

* An initial v1 schema for `app-env.yaml` is defined below in the Appendix. The platform template MUST only honor these fields and MUST NOT allow arbitrary Kubernetes manifests or resource injection.

1. **`release.yaml`** (machine-updated desired release)

* Defines the desired container image reference to deploy

  * preferably immutable digest (optionally tag + digest)
* This file is updated **only by platform automation** (v1: via the "app-env-config" Building Block)

Application teams do not provide Kubernetes manifests. The platform provides the deployment template (e.g., Helm chart) that renders the workload using `app-env.yaml` + `release.yaml`.

---

## Namespace and Ownership Policy

To enforce strong isolation and avoid privilege escalation:

* Platform-owned namespaces MUST start with the prefix: **`platform-`**
* Application namespaces MUST start with the prefix: **`app-`**

Application teams MUST NOT be able to:

* create namespaces at all, or
* create namespaces with the `platform-` prefix, or
* modify any `platform-*` namespaces.

Enforcement mechanisms:

* Kubernetes RBAC: application identities do not have permissions to create namespaces.
* Admission policies (OPA Gatekeeper / Kyverno): reject any request creating a namespace with name starting with `platform-` unless originating from a platform-controlled identity.

---

## Argo Workflows

Argo Workflows is **not required** for this architecture and is **out of scope** for the application delivery path.
If present in earlier prototypes, it should be removed to reduce complexity and to keep ArgoCD focused on deployments only.

---

## End-to-End Flow

### A) Provisioning a new application environment (“Day 0”)

**Actor: platform automation (meshStack Building Block provisioning + IaC)**

1. The platform provisions an app environment by:

   * creating the application namespace (prefix `app-...`)
   * creating the registry repository/path for that environment (Harbor RBAC: push permissions granted to the application team’s CI identity)
   * creating or updating ArgoCD configuration so the environment is reconciled from the GitOps State Repository (e.g., an ArgoCD Application or ApplicationSet)
   * registering the environment through the presence of `app-env.yaml` in the state repo (the Release Controller uses this as the mapping source)

2. The platform commits initial state into the GitOps State Repository, e.g. at (see appendix below for a scheme draft):

   * `apps/<team>/<app>/<env>/app-env.yaml`
   * `apps/<team>/<app>/<env>/release.yaml`

3. ArgoCD reconciles the desired state and creates the baseline runtime resources in the target namespace.

**Result:** the environment exists, is managed by ArgoCD, and is ready to receive releases via the registry.

---

### B) Releasing a new version (“Day 2”)

**Actor: application team (local build or Gitea Runner)**

1. The application team builds the container image outside the cluster and pushes it to the assigned Harbor repository/path for that app-env.

**Actor: platform component (Release Controller)**
2. The Release Controller detects the new image (webhook or polling).
3. The Release Controller finds the matching environment by searching the GitOps State Repository for an `app-env.yaml` whose `registry.repository` matches the pushed image repository/path.
4. It validates platform rules (at minimum: repository is known; optionally: environment gating such as “prod requires promotion tag”).
5. It updates only `release.yaml` for that environment to the new image reference and commits to the GitOps State Repository.

**Actor: platform component (ArgoCD)**
6. ArgoCD observes the Git change and deploys the prebuilt image to the target namespace.
7. ArgoCD continuously reconciles to maintain the desired state.

**Result:** developer experience is effectively “push image → platform deploys”, while Git remains the single deployment source of truth.

---

## Shared Responsibility Model

### Application Teams (Consumers)

They own:

* application code
* containerization (Dockerfile/buildpack)
* build execution (local scripts or CI on Gitea Runner)
* when a new image is produced

They do NOT:

* deploy to Kubernetes
* interact with ArgoCD
* modify GitOps desired state
* create namespaces or platform resources

Their single standard interaction point is:

> **Push an image to their assigned registry repository/path and (when they want to deploy) update the release reference via the "app-env-config" Building Block.**

---

### Platform Team (Provider)

They own:

* cluster runtime (SKE), namespace isolation, policies
* registry structure and access control
* GitOps State Repository structure and auditing
* ArgoCD configuration and reconciliation behavior
* "app-env-config" Building Block behavior and deployment gating rules (if any)
* pass-through app configuration scheme for app teams in `app-env.yaml` (e.g. number of nodes, port etc.)
* (optional) future automation for "deploy on push" (not part of v1)

---

## Consequences

### Positive

* Excellent DX: build is transparent (local/CI), deployments are controlled via a clear self-service action (app-env-config)
* Strong enterprise isolation: registry permissions + namespace policies prevent cross-team interference
* GitOps integrity: Git remains auditable and rollback-capable
* ArgoCD is simplified: deploy-only, no build complexity
* Modular platform: app-env-config can be delivered as a meshStack Building Block; the same GitOps contract can be used without meshStack by providing an alternative controlled updater

### Trade-offs

* Platform must implement and operate the controlled updater (v1: app-env-config Building Block)
* "Deploy on push" is not automatic in v1 unless an additional automation component is introduced later
* Requires explicit mapping between registry repository/path and app environments (stored in `app-env.yaml`)

---

## Explicit Non-Goals

This ADR does NOT define:

* the detailed implementation of future "deploy on push" automation (webhook vs polling etc.)
* how production promotion is implemented (tags vs digests vs signatures)
* advanced compliance gates (image signing, scanning policies)
* the full schema of `app-env.yaml` (to be defined in a follow-up spec/ADR)

These items will be handled in follow-up ADRs and implementation docs.

---

## Notes / Next Steps

* Define the initial minimal schema for `app-env.yaml` and `release.yaml` (DX-critical).
* Implement the "app-env-config" Building Block that updates `release.yaml` (and optionally safe parts of `app-env.yaml`) in the GitOps State Repository.
* Keep ArgoCD deployment templates minimal and restrict the app-team surface to the contract fields only.

---

## Appendix: GitOps Layout draft schemes (`app-env.yaml` and `release.yaml`)

### Stable Identifiers in GitOps State Paths

The GitOps state repository uses a hierarchical directory structure that mirrors the meshStack domain model
(workspace → project → tenant).

All path segments MUST be based on **stable technical identifiers** (IDs or immutable slugs),
not on human-readable display names.

Rationale:

- In meshStack, workspaces, projects, and tenants may be renamed or reorganized over time.
- GitOps state paths must remain stable to avoid accidental redeployments, drift, or loss of history.
- Human-readable names are considered presentation metadata and must not be used as addressing keys.

Therefore:

- Repository paths use `<workspace-id>`, `<project-id>`, `<tenant-id>`.
- Display names MAY be included as optional metadata inside `app-env.yaml`,
  but MUST NOT influence reconciliation or deployment logic.

Example:

```
workspaces/<workspace-id>/
projects/<project-id>/
tenants/<tenant-id>/
app-env.yaml
release.yaml
```

This structure is a **platform convention**, not a hard technical requirement.
Alternative layouts are possible by adapting the platform’s ArgoCD configuration,
without affecting application teams or build pipelines.

The GitOps state repository layout is owned by the platform team. Application teams interact only through the semantic contract defined in `app-env.yaml` (not directly, but over a defined interface/UI, e.g. Building Blocks) and `release.yaml`, not through repository paths.

### `app-env.yaml` example

```yaml
apiVersion: idp.meshcloud.io/v1alpha1
kind: AppEnvironment

metadata:
  name: app1-dev                 # Human-friendly env name, unique within tenant.
  tenant: team-a                 # Tenant / team identifier used for scoping.
  app: app1                      # Application identifier.
  environment: dev               # dev | staging | prod (platform-defined set).

spec:
  # --- Ownership / Target (platform-controlled boundary) ---
  target:
    namespace: app-team-a-app1-dev   # MUST start with "app-" (enforced by policy).
    cluster: ske-main                # Optional if single-cluster; useful later.

  # --- Registry mapping (used by the Release Controller) ---
  registry:
    provider: harbor
    repository: harbor.example.tld/team-a/app1/dev  # Exact repo/path that triggers this env.
    deployPolicy:
      mode: auto                     # auto | manual (manual for prod)
      # manual means: controller only deploys on explicit promotion signal (defined elsewhere)
      # keep details out of v1 to avoid overfitting.

  # --- Runtime shape (what the app team can influence safely) ---
  runtime:
    service:
      port: 8080                     # Container port exposed as service.
      protocol: http                 # http | grpc (optional enum for platform templates)

    scaling:
      replicas: 2                    # Simple v1 scaling. (Autoscaling deferred to v2)

    resources:
      requests:
        cpu: "200m"
        memory: "256Mi"
      limits:
        cpu: "1000m"
        memory: "512Mi"

  # --- Exposure (optional) ---
  ingress:
    enabled: true
    host: app1-dev.example.tld
    path: /
    # tls handling is platform-specific; v1 keeps it simple:
    tls:
      enabled: true

  # --- Configuration wiring (12-factor) ---
  config:
    env:
      # A small allow-list of explicit env vars (non-secret).
      - name: LOG_LEVEL
        value: info
      - name: FEATURE_X_ENABLED
        value: "true"

    buildingBlocks:
      # References to meshStack building blocks providing env vars/secrets.
      # The platform decides how these references resolve (e.g., envFrom, ExternalSecrets, etc.).
      - ref: postgres-default         # Example BB instance name
      - ref: observability-basic      # Example BB instance name

  # --- Release channel (optional in v1, but good for clarity) ---
  release:
    track: stable                    # stable | canary (future use), informational in v1
```

---

### Fields and Constraints

#### Required (v1)

* `metadata.tenant`, `metadata.app`, `metadata.environment`
* `spec.target.namespace` (MUST start with `app-`)
* `spec.registry.repository` (unique mapping to this env)
* `spec.runtime.service.port`
* `spec.runtime.scaling.replicas`
* `spec.runtime.resources.requests/limits` (Enterprise: enforce via policy)

#### Optional (v1)

* `ingress.*`
* `config.env`
* `config.buildingBlocks`
* `registry.deployPolicy.mode` (default `auto` for dev/staging, `manual` for prod)

#### Platform-enforced constraints (important!)

* Namespace creation is platform-owned; app teams cannot create namespaces.
* The Release Controller matches `registry.repository` → env; if multiple matches exist, it MUST fail safe (no deploy).
* `app-env.yaml` is owned by the platform (or edited via controlled self-service), not by app teams directly.

---

### Rationale

The `app-env.yaml` schema is intentionally **opinionated, minimal, and restrictive**. Its purpose is to enable strong enterprise controls while still giving application teams meaningful influence over their runtime environments.

**Key design decisions:**

1. **Human-centric, not Kubernetes-centric**
   The schema models *application environments*, not Kubernetes objects.
   Application teams reason about replicas, resources, ports, ingress, and configuration—not Deployments, Services, or CRDs. Kubernetes remains an implementation detail owned by the platform.

2. **Clear separation of concerns between configuration and release**
   Runtime configuration (`app-env.yaml`) is separated from release state (`release.yaml`).
   This allows the Release Controller to update releases independently, without modifying environment configuration, improving auditability and reducing merge conflicts.

3. **Explicit registry-to-environment mapping**
   The registry repository/path is declared directly in `app-env.yaml`.
   This makes ownership and deployment scope transparent and discoverable, and enables the Release Controller to deterministically map registry events to exactly one application environment.

4. **Limited but sufficient developer influence**
   The schema exposes only those parameters that application teams legitimately need in enterprise environments (scaling, resources, ingress, configuration wiring).
   Arbitrary Kubernetes manifests, custom resources, or cluster-level settings are deliberately excluded to prevent policy bypass and platform drift.

5. **12-factor aligned configuration model**
   Application configuration is expressed via environment variables and platform-provided building blocks.
   Secrets, credentials, and service bindings are resolved by the platform, not embedded in application code or deployment descriptors.

6. **Designed for evolution, not completeness**
   The v1 schema prioritizes simplicity and safety over feature completeness.
   More advanced concerns (autoscaling policies, canary releases, maintenance windows, compliance gates) are intentionally deferred to future schema versions, once the core platform patterns are proven.

---

### Companion file: `release.yaml` (for completeness)

```yaml
apiVersion: idp.meshcloud.io/v1alpha1
kind: AppRelease

metadata:
  tenant: team-a
  app: app1
  environment: dev

spec:
  image:
    repository: harbor.example.tld/team-a/app1/dev
    tag: "2025.12.29-1342"          # Optional if digest present
    digest: "sha256:..."            # Preferred immutable reference
    # effective ref = repo@digest (or repo:tag if digest missing)
  observedAt: "2025-12-29T13:42:10Z"
  observedBy: platform-release-controller
```

**Rule:** `release.yaml` is **written only** by the Release Controller.
