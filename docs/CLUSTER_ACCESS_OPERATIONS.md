# Cluster Access: Operations Manual

This document explains how long-term cluster access works in the IDP demo.

## Problem

- **Short-term credentials:** SKE kubeconfig has ~8h validity period
- **Production readiness:** A platform that becomes undeployable after 8h is not production-ready
- **Automation:** Terraform must reliably manage K8s resources over weeks/months

## Solution: ServiceAccount-Based Access

See **ADR-003** (Cluster Access Strategy) for technical details and **ADR-004** (Layer Integration Pattern) for Terraform layer decoupling.

---

## Workflow: Lokale Entwicklung

### Phase 1: Validate (optional)

```bash
make validate
```

Stellt sicher, dass beide Layer syntaktisch korrekt sind.

### Phase 2: Deploy Bootstrap

```bash
make bootstrap
```

**Was passiert:**
1. SKE-Cluster wird erstellt (~10 min)
2. Harbor Registry wird konfiguriert
3. Terraform exportiert:
   - `cluster_endpoint`: K8s API URL
   - `cluster_ca_certificate`: CA-Zertifikat
   - `registry_url`: Harbor Registry URL
   - Weitere Outputs

### Phase 3: Deploy App-Env

```bash
make app-env
```

**Was das Makefile macht:**
1. ✅ Checkt dass Bootstrap deployed ist
2. ✅ Liest Bootstrap's `terraform.tfstate` und extrahiert Outputs
3. ✅ Schreibt Outputs in `app-env/terraform.tfvars.auto.json`
4. ✅ Deployed App-Env mit diesen Inputs

**Was App-Env deployt:**
1. RBAC: `terraform-admin` ServiceAccount + ClusterRole
2. Kubernetes Secret für den Token
3. Namespace `demo-app`
4. ImagePullSecret für Harbor Registry

### Phase 4: Zukünftige Deployments

```bash
cd demo/terraform/app-env

# Token aus Cluster Secret auslesen (oder Secrets Manager)
TOKEN=$(kubectl get secret terraform-admin-token -n kube-system \
  -o jsonpath='{.data.token}' | base64 -d)

# Deploy
terraform apply -var="cluster_admin_token=$TOKEN"
```

**Wichtig:** 
- ✅ Bootstrap läuft weiterhin im Hintergrund (State File ist Source of Truth)
- ✅ App-Env wird via `terraform_remote_state` automatisch mit Bootstrap verbunden
- ✅ Keine Skripte, keine tfvars-Manipulation, keine enge Kopplung

---

## Technische Details

### Integration: terraform_remote_state

```hcl
# app-env/main.tf
data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config = {
    path = var.bootstrap_state_path  # "../bootstrap/terraform.tfstate"
  }
}

# Automatisch: cluster_endpoint vom bootstrap lesen
host = data.terraform_remote_state.bootstrap.outputs.cluster_endpoint
```

**Wie es funktioniert:**
- App-Env definiert `bootstrap_state_path = "../bootstrap/terraform.tfstate"` (Variable mit Default)
- Wenn app-env deployed wird, liest Terraform automatisch Bootstrap's State
- Keine Abhängigkeit auf Skripte oder tfvars-Schreiben
- Hybrid-Fallback: Falls `cluster_endpoint` direkt übergeben, nutze das statt Remote State

### Credential Lifecycle

| Komponente | Lebensdauer | Verwaltung | Nutzung |
|---|---|---|---|
| SKE kubeconfig (Client-Cert) | ~8h | Von SKE Provider generiert | Admin kubectl (nur lokal) |
| terraform-admin Token | Unbegrenzt | In K8s Secret gespeichert | Terraform Automation |
| Bootstrap State | Unbegrenzt | In Filesystem/Backend | terraform_remote_state |

**Fluss:**

```
Bootstrap:
  kubeconfig (8h) --> [Initial RBAC Setup] --> create terraform-admin Token

App-Env:
  terraform-admin Token (persistent) --> [stored in Secret] --> [used every deployment]
```

---

## Admin-Zugang (kubectl)

Falls ein Admin manuell in den Cluster muss:

```bash
# Fresh kubeconfig aus STACKIT holen
cd demo/terraform/bootstrap
terraform refresh  # Aktualisiert kubeconfig

# Jetzt kann admin manuell kubectl-Befehle ausführen
KUBECONFIG=../kubeconfig kubectl get nodes
```

---

## Troubleshooting

### "Unauthorized" beim terraform apply

**Ursache:** Token ist abgelaufen oder ungültig

**Lösung:**

```bash
# 1. Prüfe ob Token noch in Secret existiert
kubectl get secret terraform-admin-token -n kube-system -o jsonpath='{.data.token}'

# 2. Falls Secret fehlt: Starte app-env wieder mit frischer kubeconfig
cd demo/terraform/app-env
terraform destroy  # Nur RBAC-Ressourcen
terraform apply   # Erstellt neue Token

# 3. Exportiere neuen Token
terraform output -raw service_account_token

# 4. Nutze neuen Token für zukünftige Runs
terraform apply -var="cluster_admin_token=$TOKEN"
```

### kubeconfig läuft ab

**Für Admin-Zugang:**
```bash
cd demo/terraform/bootstrap
terraform refresh
```

**Für Automation:** Kein Problem, solange ServiceAccount-Token gültig ist. Die neue `terraform_remote_state`-Integration kümmert sich automatisch darum.

### terraform_remote_state kann State nicht lesen

**Ursache:** Bootstrap wurde noch nicht deployed, oder State-Path ist falsch

**Lösung:**
```bash
# 1. Stelle sicher dass Bootstrap deployed ist
cd demo/terraform/bootstrap && terraform apply

# 2. Überprüfe State-Path
cd demo/terraform/app-env && terraform console
> data.terraform_remote_state.bootstrap.outputs.cluster_endpoint
# Sollte die API-URL zeigen

# 3. Falls immer noch Problem: übergebe Werte direkt
terraform apply -var="cluster_endpoint=https://..." \
                -var="cluster_ca_certificate=..." \
                -var="cluster_admin_token=$TOKEN"
```

---

## Best Practices

1. **Nie kubeconfig in Git committen** → wird ungültig + unsicher
2. **ServiceAccount-Token sicher speichern** → Vault, Secrets Manager, Encrypted Git
3. **Regelmäßig testen** → `terraform plan` mindestens weekly
4. **Monitoring** → Logs wenn ServiceAccount-Token rotation erforderlich
5. **Keine Skripte für tfvars-Manipulation** → nutze `terraform_remote_state` oder direkte Variablen
6. **terraform.tfstate Backup** → State ist Quelle aller Wahrheit

---

## Building Blocks / meshStack Migration

Die aktuelle Architektur ist **zukunftssicher für meshStack**:

```hcl
# In meshStack: Direct Module Wiring statt terraform_remote_state
module "app-env" {
  source = "git::https://...app-env"
  
  cluster_endpoint        = module.bootstrap.cluster_endpoint
  cluster_ca_certificate  = module.bootstrap.cluster_ca_certificate
  cluster_admin_token     = var.bootstrap_admin_token
  
  depends_on = [module.bootstrap]
}
```

**Code ändert sich nicht!** Nur Integration-Mechanik wechselt von `terraform_remote_state` zu direktem Modul-Output.

---

## Zukünftige Verbesserungen

- [ ] Token-Rotation automatisieren (Kubernetes CronJob)
- [ ] Secrets Manager Integration (Vault, AWS Secrets)
- [ ] OIDC-federierte ServiceAccounts (falls STACKIT unterstützt)
- [ ] Multi-Tenant RBAC (pro-App ServiceAccounts statt Cluster-Admin)
- [ ] Remote Backend Support für terraform_remote_state (S3, Terraform Cloud, etc.)

