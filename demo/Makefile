.PHONY: provision configure app-env down validate help

# ============================================================================
# Makefile: Provision & Configuration Orchestration
# ============================================================================
# Implements the Provision/Configuration pattern from ADR-002
#
# Three independent Terraform layers orchestrated in sequence:
# 1. Provision (bootstrap/platform/provision)     - Infrastructure
# 2. Configure (bootstrap/platform/configure)     - Platform initialization
# 3. App-Env   (app-env)                          - Application environments
#
# Each layer is completely independent and communicates only through
# explicit input/output variables injected via terraform.tfvars files.
# ============================================================================

help:
	@echo "STACKIT IDP Demo - Provision & Configuration Pattern"
	@echo ""
	@echo "Targets:"
	@echo "  make provision       - Deploy infrastructure (SKE cluster, Harbor)"
	@echo "  make configure       - Initialize platform (ServiceAccount, RBAC)"
	@echo "  make app-env         - Deploy application environment"
	@echo "  make kubeconfig      - Generate kubeconfig for testing (shows export command)"
	@echo "  make test-connection - Test cluster connectivity"
	@echo "  make validate        - Validate all layers"
	@echo "  make down            - Destroy all layers (reverse order)"
	@echo ""
	@echo "Workflow:"
	@echo "  make provision → make configure → make app-env → make test-connection"
	@echo ""
	@echo "Testing:"
	@echo "  make kubeconfig      # Generate and show export command"
	@echo "  eval \"\$$(make kubeconfig)\"  # Set KUBECONFIG env variable"
	@echo "  kubectl get ns       # Use kubectl with proper credentials"
	@echo ""
	@echo "Documentation:"
	@echo "  docs/adr/ADR-002_bootstrap-platform-components.md"
	@echo "  terraform/README.md"

provision:
	@echo "🚀 Phase A: Provisioning infrastructure..."
	@echo ""
	cd terraform/bootstrap/platform/provision && \
		terraform init -upgrade=false && \
		terraform validate && \
		terraform apply -auto-approve
	@echo ""
	@echo "✅ Provision layer deployed"

configure: _check-provision _inject-provision-to-configure
	@echo "🚀 Phase B: Configuring platform..."
	@echo ""
	cd terraform/bootstrap/platform/configure && \
		terraform init -upgrade=false && \
		terraform validate && \
		terraform apply -auto-approve
	@echo ""
	@echo "✅ Configuration layer deployed"

app-env: _check-configure _inject-configure-to-appenv
	@echo "🚀 Phase C: Deploying application environment..."
	@echo ""
	cd terraform/app-env && \
		terraform init -upgrade=false && \
		terraform validate && \
		terraform apply -auto-approve
	@echo ""
	@echo "✅ App-Env layer deployed"

kubeconfig: _check-configure _generate-kubeconfig _show-kubeconfig-export

test-connection: _check-configure _generate-kubeconfig _test-kubectl
	@echo "✅ All connection tests passed"

_check-provision:
	@if [ ! -f terraform/bootstrap/platform/provision/terraform.tfstate ]; then \
		echo "❌ Provision layer not deployed. Run 'make provision' first."; \
		exit 1; \
	fi
	@echo "✅ Provision state found"

_check-configure:
	@if [ ! -f terraform/bootstrap/platform/configure/terraform.tfstate ]; then \
		echo "❌ Configure layer not deployed. Run 'make configure' first."; \
		exit 1; \
	fi
	@echo "✅ Configure state found"

_inject-provision-to-configure:
	@echo "📝 Injecting Provision outputs into Configure..."
	python3 scripts/inject-provision-to-configure.py

_inject-configure-to-appenv:
	@echo "📝 Injecting Configure outputs into App-Env..."
	python3 scripts/inject-configure-to-appenv.py

_generate-kubeconfig:
	@echo "🔑 Generating kubeconfig with platform-terraform token..."
	@python3 scripts/generate-test-kubeconfig.py

_show-kubeconfig-export:
	@echo ""
	@echo "📋 To use kubectl with proper credentials, run:"
	@echo ""
	@echo "  export KUBECONFIG=/tmp/kubeconfig-token"
	@echo ""
	@echo "Or in one line:"
	@echo ""
	@echo "  eval \"\$$(make kubeconfig)\" && echo 'export KUBECONFIG=/tmp/kubeconfig-token'"
	@echo ""
	@echo "Then test with:"
	@echo "  kubectl get ns"
	@echo "  kubectl get ns demo-app"
	@echo ""

_test-kubectl:
	@echo "🧪 Testing kubectl connectivity..."
	@export KUBECONFIG=/tmp/kubeconfig-token; \
	echo "  → cluster-info..."; \
	if kubectl cluster-info 2>&1 | grep -q "Kubernetes"; then \
		echo "    ✓ Cluster reachable"; \
	else \
		echo "    ⚠ Cluster info available"; \
	fi; \
	echo "  → namespaces..."; \
	if kubectl get ns 2>&1 | grep -q "demo-app"; then \
		echo "    ✓ demo-app namespace found"; \
	else \
		echo "    ✗ demo-app namespace not found"; \
		exit 1; \
	fi; \
	echo "  → resourcequota..."; \
	if kubectl get resourcequota -n demo-app 2>&1 | grep -q "demo-app-quota"; then \
		echo "    ✓ ResourceQuota configured"; \
	else \
		echo "    ⚠ ResourceQuota not configured"; \
	fi; \
	echo "  → networkpolicies..."; \
	if kubectl get networkpolicies -n demo-app 2>&1 | grep -q "deny"; then \
		echo "    ✓ NetworkPolicies configured"; \
	else \
		echo "    ⚠ NetworkPolicies not configured"; \
	fi; \
	echo ""

validate:
	@echo "🔍 Validating Provision layer..."
	cd terraform/bootstrap/platform/provision && \
		terraform init -upgrade=false && \
		terraform validate
	@echo "✅ Bootstrap/Provision valid"
	@echo ""
	@echo "🔍 Validating Configure layer..."
	cd terraform/bootstrap/platform/configure && \
		terraform init -upgrade=false && \
		terraform validate
	@echo "✅ Bootstrap/Configure valid"
	@echo ""
	@echo "🔍 Validating App-Env layer..."
	cd terraform/app-env && \
		terraform init -upgrade=false && \
		terraform validate
	@echo "✅ App-Env valid"
	@echo ""
	@echo "✅ All layers valid"

.PHONY: test-connection _generate-kubeconfig _test-kubectl _show-kubeconfig-export

down: _destroy-appenv _destroy-configure _destroy-provision
	@echo "✅ All layers destroyed"

_destroy-appenv:
	@if [ -f terraform/app-env/terraform.tfstate ]; then \
		echo "🗑️  Destroying App-Env layer..."; \
		cd terraform/app-env && \
			terraform destroy -auto-approve && \
			rm -f terraform.auto.tfvars.json; \
		echo "✅ App-Env destroyed"; \
	else \
		echo "ℹ️  App-Env not deployed"; \
	fi

_destroy-configure:
	@if [ -f terraform/bootstrap/platform/configure/terraform.tfstate ]; then \
		echo "🗑️  Destroying Configure layer..."; \
		cd terraform/bootstrap/platform/configure && \
			terraform destroy -auto-approve && \
			rm -f terraform.auto.tfvars.json; \
		echo "✅ Configure destroyed"; \
	else \
		echo "ℹ️  Configure not deployed"; \
	fi

_destroy-provision:
	@if [ -f terraform/bootstrap/platform/provision/terraform.tfstate ]; then \
		echo "🗑️  Destroying Provision layer..."; \
		cd terraform/bootstrap/platform/provision && \
			terraform destroy -auto-approve; \
		echo "✅ Provision destroyed"; \
	else \
		echo "ℹ️  Provision not deployed"; \
	fi
