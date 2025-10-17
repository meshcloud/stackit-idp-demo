.PHONY: bootstrap app-env app-env-vars destroy-app-env destroy-bootstrap

# 🛠️ Makefile: Vereinfacht das Ausführen der Terraform-Stacks.
# - `make bootstrap`    → Provisioniert Basisinfrastruktur (Cluster, Registry)
# - `make app-env`      → Führt App-Umgebung über TF_VAR-Wrapper aus
# - `make app-env-vars` → Alternativ: Übergabe via .auto.tfvars.json-Datei
# - `make destroy-*`    → Entfernt jeweilige Stacks

bootstrap:
	cd terraform/bootstrap && terraform init && terraform apply -auto-approve

# Option A: via TF_VAR_…
app-env:
	./scripts/app-env-apply.sh

# Option B: via .auto.tfvars.json
app-env-vars:
	./scripts/mk-app-env-vars.sh
	cd terraform/app-env && terraform init && terraform apply -auto-approve

destroy-app-env:
	cd terraform/app-env && terraform destroy -auto-approve

destroy-bootstrap:
	cd terraform/bootstrap && terraform destroy -auto-approve

	