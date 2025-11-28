# **ADR-001 — Harbor Registry Project Strategy (Platform-Level vs. App-Level)**

**Status:** Accepted
**Date:** 2025-11-18  
**Updated:** 2025-11-28
**Context:** Sovereign Developer Platform (STACKIT-based IDP Demo)

---

## **1. Decision**

For the initial version of the Sovereign Developer Platform (bootstrap + app-env),
we use **one pre-existing shared Harbor registry project**:

```
Harbor Project: registry
```

All application environments (app-env) will push and pull images from repositories inside this single project.

Example:

```
registry/my-app
registry/dev-portal
registry/aider-proxy
registry/demo-service
```

A single **pre-existing Robot Account** (`robot$registry+robotaccount`) is used by:

* GitHub Actions CI pipelines (image push)
* ArgoCD (image pull)
* All application namespaces (image pull)

---

## **2. Rationale**

### **Why a shared Harbor project (for now)?**

* **Simplifies the demo setup:**
  Only one registry endpoint and one robot account must be wired into all modules.

* **Faster development and onboarding:**
  Less duplication of terraform modules, fewer credentials, fewer cross-module dependencies.

* **Cleaner Webinar Story:**
  Platform team provisions *one* sovereign registry; developer workspaces consume it automatically.

* **STACKIT Harbor uses OIDC authentication:**
  STACKIT Harbor runs in strict OIDC mode (`auth_mode: oidc_auth`) with STACKIT IDP.
  No admin username/password credentials are available for automated Harbor resource management.
  Harbor Terraform provider cannot be used without admin credentials.
  **Solution:** Use manually created Harbor project and robot account, pass credentials via environment variables.

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

👉 **One pre-existing shared Harbor project (`registry`) with manually created robot account.**

The Harbor project and robot account are **NOT managed by Terraform** due to STACKIT Harbor's OIDC-only authentication model.

**Implementation:**
- Harbor project `registry` - manually created via STACKIT Harbor UI
- Robot account `robot$registry+robotaccount` - manually created via Harbor UI
- Credentials stored in environment variables: `HARBOR_ROBOT_USERNAME` and `HARBOR_ROBOT_TOKEN`
- All platform modules consume credentials from environment (no Terraform Harbor provider needed)

**Deployment modules:**
- `platform/00-state-bucket` - S3 backend for Terraform state
- `platform/01-ske` - STACKIT Kubernetes Engine cluster
- `platform/02-meshstack` - meshStack integration
- `platform/03-argocd` - ArgoCD with Harbor pull secret (uses env vars)
- `platform/99-harbor-deprecated` - **SKIPPED** - Harbor Terraform module not usable with OIDC Harbor

The architecture supports future migration to:
* per-app registry projects, or
* per-team/per-tenant registry projects

when admin credentials or alternative automation approaches become available.

---

## **6. Notes**

* **STACKIT Harbor Authentication:** Uses OIDC with STACKIT IDP (`auth_mode: oidc_auth`), Harbor v2.13.0
* **Manual Setup Required:** Harbor project and robot account must be created through Harbor UI
* **No Terraform Management:** Harbor Terraform provider requires admin credentials (username/password) which are not available in OIDC mode
* **Credential Flow:** Environment variables → Terragrunt → Kubernetes secrets (in ArgoCD namespace and app namespaces)
* Robot account credentials are the **only** credentials needed for all operations (push/pull)
* The chosen approach aligns well with the first meshStack Building Block prototype:
  *bootstrap = platform resources; app-env = per-workspace resources.*

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

### **7.2 All cross-module integrations must use variables (not Terraform dependencies)**

Harbor credentials are not managed by Terraform, therefore modules cannot use Terraform `dependency` blocks for Harbor.

**Current Implementation:**
Harbor credentials flow via environment variables:

```bash
# In platform/.env
HARBOR_ROBOT_USERNAME=robot$registry+robotaccount
HARBOR_ROBOT_TOKEN=<token>
```

```hcl
# In terragrunt.hcl files
inputs = {
  harbor_robot_username = get_env("HARBOR_ROBOT_USERNAME")
  harbor_robot_token    = get_env("HARBOR_ROBOT_TOKEN")
}
```

**Reason:**
- STACKIT Harbor uses OIDC → no admin credentials → no Terraform provider usage
- Environment variables provide clean separation between manual setup and automated deployment
- Future automation (if admin credentials become available) can replace env vars with Terraform outputs

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

### **7.4 Robot accounts are created manually (not via Terraform)**

Due to STACKIT Harbor's OIDC authentication model, Harbor projects and robot accounts cannot be managed via Terraform.

**Current Process:**
1. Manually create Harbor project via STACKIT Harbor UI
2. Manually create robot account in Harbor UI
3. Store credentials in `platform/.env`:
   - `HARBOR_ROBOT_USERNAME=robot$registry+robotaccount`
   - `HARBOR_ROBOT_TOKEN=<token>`
4. Terraform modules consume credentials from environment variables

**Reason:**
Robot accounts are project-scoped and require admin credentials for automation. STACKIT Harbor's OIDC-only mode prevents Terraform provider usage. This manual approach ensures demo/PoC viability while maintaining clean separation of credentials from code.

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
