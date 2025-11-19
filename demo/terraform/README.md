# Platform Bootstrap — Provision & Configuration Pattern

This directory follows the **Provision & Configuration** pattern defined in  
**ADR-002: Bootstrap Platform Components & Architecture Boundary**.  
Please read ADR-002 for the full rationale and architectural decisions.

This README provides only the *practical overview* needed by contributors.

---

## Directory Structure

```

demo/terraform/
bootstrap/
platform/
provision/    # Phase A — Provision platform infrastructure
configure/    # Phase B — Configure platform internals
app-env/
main/           # Application environment provisioning

```

---

## Concept Overview

```
      +--------------------------+
      |  Provision Layer (A)     |
      |--------------------------|
      | - Create infra: SKE,     |
      |   Harbor, KMS*, DNS*,…   |
      | - No Kubernetes provider |
      | - Outputs: host, CA,     |
      |   bootstrap token        |
      +-------------+------------+
                    |
                    v
      +--------------------------+
      | Configuration Layer (B)  |
      |--------------------------|
      | - Connect to cluster     |
      | - Create platform SA     |
      | - Create RBAC + policies |
      | - Output stable SA token |
      +-------------+------------+
                    |
                    v
      +--------------------------+
      | App-Env Layer           |
      |--------------------------|
      | - Uses platform SA       |
      | - Creates namespaces,    |
      |   quotas, networkpolicy, |
      |   app-specific resources |
      +--------------------------+
```

(*planned components)

---

## When to use which layer

- **Provision Layer:**  
  Use when a resource is created *from the cloud control plane*  
  (e.g., SKE cluster, Harbor registry, KMS instance, DNS zones).

- **Configuration Layer:**  
  Use when configuring the **inside** of a resource  
  (e.g., K8s namespaces, RBAC, ArgoCD bootstrap, DB schema, Vault engines).

- **App-Env Layer:**  
  Anything environment-specific (namespaces, app policies, quotas, RBAC, etc.)

---

## Local Usage (Makefile)

```

make provision    # Run Phase A
make configure    # Run Phase B
make app-env      # Deploy application environments

```

---

## Coding Guidelines

- All Terraform code, comments, and docs **must be in English**.
- The Provision Layer must **never** use the Kubernetes provider.
- Modules must remain decoupled and communicate only through **explicit inputs/outputs**.
- App-env must **not** create cluster-wide ServiceAccounts.

---

*For full details, motivation, and architectural constraints, see ADR-002.*
