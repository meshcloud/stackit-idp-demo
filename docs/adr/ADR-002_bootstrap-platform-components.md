# ADR-002 — Bootstrap Platform Components Scope

**Status:** Proposed  
**Date:** 2025-11-18

## Decision

Bootstrap provisioning will include:

1. **SKE Kubernetes Cluster** (required)
2. **Harbor Registry** (required, as per ADR-001)
3. **Secret Store (KMS)** (planned, not yet implemented)
4. **Argo CD** (planned, not yet implemented)
5. **Observability/Monitoring** for SKE cluster (planned, not yet implemented)
6. **DNS Zone** (planned, not yet implemented)

For **MVP (demo ready)**: Only SKE + Harbor are provisioned.

## Rationale

These components are **platform-level** (shared across all app-env workspaces):

- Each app-env needs to pull images → Harbor is bootstrap-level
- Each app-env needs to store secrets → KMS should be bootstrap-level
- GitOps requires cluster-wide operator → Argo CD is bootstrap-level
- Apps need externally accessible endpoints → DNS is bootstrap-level

## Implementation Notes

- **KMS/Secret Store**: Can use STACKIT KMS or external solution (Vault)
- **Argo CD**: Once Helm provider issues are resolved (see TECHNICAL DEBT)
- **DNS**: Depends on DNS provider (Route53, STACKIT DNS, etc.)

## Future Work

- [ ] Add KMS provisioning to bootstrap
- [ ] Add Argo CD deployment to bootstrap (resolve Helm provider issues first)
- [ ] Add observability to SKE cluster (monitoring)
- [ ] Add DNS zone provisioning to bootstrap
- [ ] Document each component's outputs for app-env consumption
