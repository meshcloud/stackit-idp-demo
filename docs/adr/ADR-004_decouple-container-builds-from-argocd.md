# ADR-004 Decouple container builds from ArgoCD

## Status
Proposed

## Context
Today, app container builds run inside the Kubernetes cluster (Argo Workflows), which is slow, hard to debug for developers, and tightly couples build failures to deployment availability.

## Decision
Move container builds out of the cluster.
- Build & push happens in the app repo (local script now, Gitea runner later).
- GitOps state repo holds the desired deployed image tag.
- ArgoCD only deploys prebuilt images.

## Consequences
- Faster, cacheable builds with transparent logs
- ArgoCD focuses on GitOps deployments
- Clear separation between build and deploy
