#!/usr/bin/env python3
"""
Inject Provision layer outputs into Configure layer terraform.auto.tfvars.json
"""
import json
import os
import sys

def main():
    # Read provision state
    provision_state_path = "terraform/bootstrap/platform/provision/terraform.tfstate"
    if not os.path.exists(provision_state_path):
        print(f"❌ Provision state not found: {provision_state_path}")
        sys.exit(1)
    
    with open(provision_state_path) as f:
        state = json.load(f)
    
    outputs = state.get("outputs", {})
    
    # Extract outputs
    tfvars = {
        "kube_host": outputs.get("kube_host", {}).get("value"),
        "cluster_ca_certificate": outputs.get("cluster_ca_certificate", {}).get("value"),
        "bootstrap_client_certificate": outputs.get("bootstrap_client_certificate", {}).get("value"),
        "bootstrap_client_key": outputs.get("bootstrap_client_key", {}).get("value"),
    }
    
    # Write to configure tfvars (correct filename: *.auto.tfvars.json)
    configure_tfvars_path = "terraform/bootstrap/platform/configure/terraform.auto.tfvars.json"
    with open(configure_tfvars_path, "w") as f:
        json.dump(tfvars, f, indent=2)
    
    print(f"✅ Configure inputs injected ({configure_tfvars_path})")

if __name__ == "__main__":
    main()
