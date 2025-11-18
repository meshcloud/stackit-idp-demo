# **ADR-001 — Harbor Registry Project Strategy (Platform-Level vs. App-Level)**

**Status:** Proposed
**Date:** 2025-11-18
**Context:** Sovereign Developer Platform (STACKIT-based IDP Demo)

---

## **1. Decision**

For the initial version of the Sovereign Developer Platform (bootstrap + app-env),
we provision **one shared Harbor registry project** during the *bootstrap* phase:

```
Harbor Project: platform-demo
```

All application environments (app-env) will push and pull images from repositories inside this single project.

Example:

```
platform-demo/my-app
platform-demo/dev-portal
platform-demo/aider-proxy
platform-demo/demo-service
```

A single **Robot Account** will be created and used by:

* Tiny CI / local build pipeline
* Argo CD (image pull)
* Helm charts in app-env

---

## **2. Rationale**

### **Why a shared Harbor project (for now)?**

* **Simplifies the demo setup:**
  Only one registry endpoint and one robot account must be wired into all modules.

* **Faster development and onboarding:**
  Less duplication of terraform modules, fewer credentials, fewer cross-module dependencies.

* **Cleaner Webinar Story:**
  Platform team provisions *one* sovereign registry; developer workspaces consume it automatically.

* **Avoids current STACKIT Harbor quirks:**
  STACKIT Harbor runs in strict OIDC mode → robot accounts must be created by an admin user.
  Using one project avoids repeated OIDC logins and reduces token complexity.

---

## **3. Consequences**

### **Positive Consequences**

* Minimum viable product becomes achievable quickly.
* Local developer experience (“Tiny CI → ArgoCD → running app”) becomes extremely predictable.
* Clear separation of concerns:

  * *bootstrap* = platform infrastructure
  * *app-env* = environment provisioning
* Reduces cognitive overhead while designing the full meshStack building block architecture.

### **Negative Consequences / Risks**

* **Low isolation between applications:**
  Robot account has permissions on all repos → not ideal for production compliance.

* **Shared policies:**
  Retention, quotas, vulnerability scanning apply to the entire project.

* **Reduced multi-tenancy support:**
  Harder to explain in regulated or multi-authority scenarios (“shared registry for all workloads”).

* **Migration required later:**
  If per-app or per-team isolation becomes necessary, repos need to be moved or rebuilt.

---

## **4. Future Options**

This ADR explicitly allows and encourages future refinement.

### **Option A — Harbor Project per Application (App-Level)**

Each `app-env` invocation creates a dedicated Harbor project.

Pros:

* Strongest isolation
* Per-team retention/security policies
* Least privilege robot accounts

Cons:

* More complex bootstrap
* More Terraform modules
* Increased operator overhead

This option is compatible with meshStack’s Building Block pattern.

---

### **Option B — Harbor Project per Business Area / Tenant**

Example:

```
sovereign-cloud/
developer-productivity/
ai-services/
```

This hits a sweet spot:

* Better isolation
* Clean governance
* Still manageable number of projects

---

## **5. Decision Outcome**

For the **demo**, **PoC**, and **early internal implementations**,
we adopt:

👉 **One shared Harbor project (`platform-demo`) provisioned in bootstrap.**

The Terraform architecture will be kept modular so that:

* switching to per-app registry projects, or
* switching to per-team/per-tenant registry projects

can be implemented later with minimal refactoring (primarily changing module call locations).

---

## **6. Notes**

* The chosen approach aligns well with the first meshStack Building Block prototype:
  *bootstrap = platform resources; app-env = per-workspace resources.*
* Robot accounts will be the authoritative credential mechanism;
  OIDC/CLI secrets are used only to bootstrap the robot accounts.

---

## **7. Implementation Principles (for Terraform Modules & Future Extensibility)**

To ensure future flexibility (e.g., switching from a single shared Harbor project to per-app/per-team projects), all Terraform modules must follow these principles:

### **7.1 No hard-coded resource names**

All registry- or app-related names must be passed via module input variables:

```
variable "harbor_project_name" {}
variable "app_name" {}
variable "namespace" {}
```

**Reason:**
Allows relocation of Harbor project creation from `bootstrap` to `app-env` without code duplication.

---

### **7.2 All cross-module integrations must use outputs**

No module may reference another module by path or internal structure.
Instead:

```
output "registry_url" {}
output "robot_username" {}
output "robot_token" {}
```

And in app-env:

```
registry_url    = module.bootstrap.registry_url
robot_username  = module.bootstrap.robot_username
robot_token     = module.bootstrap.robot_token
```

**Reason:**
To allow isolation levels (platform-level → team-level → app-level) to be changed *without breaking module dependencies*.

---

### **7.3 Registry access must always be parameterized**

Images must be expressed as:

```
"${var.registry_url}/${var.harbor_project_name}/${var.app_name}:${var.image_tag}"
```

Never:

```
"platform-demo/my-app"
```

**Reason:**
Later registry-per-app or registry-per-tenant layouts become trivial.

---

### **7.4 Robot accounts must be created in the same module where the Harbor project is created**

And their credentials must be exported as outputs.

**Reason:**
Robot accounts are project-scoped → ensures separation of duties and allows future isolation without affecting CI/ArgoCD logic.

---

### **7.5 All “bootstrap” decisions must be reversible**

Meaning:

* The bootstrap cluster (SKE)
* The bootstrap registry project
* The bootstrap robot account
* ArgoCD installation

… must **not assume** they are “global forever”.

**Reason:**
This enables:

* per-tenant clusters,
* per-business-area registries,
* multi-platform IDP deployments
  without refactoring the architecture.

---

### **7.6 Modules must stay side-effect free**

Modules should never:

* write to global files except explicit outputs
* modify unrelated namespaces
* assume admin-level access beyond their intended scope

This is essential so future meshStack *Building Blocks* can wrap these modules cleanly.
