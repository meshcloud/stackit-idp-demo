#!/usr/bin/env python3
"""
Inject Configure layer outputs into App-Env layer terraform.auto.tfvars.json
"""
import json
import os
import sys

def main():
    # Read configure state
    configure_state_path = "terraform/bootstrap/platform/configure/terraform.tfstate"
    if not os.path.exists(configure_state_path):
        print(f"❌ Configure state not found: {configure_state_path}")
        sys.exit(1)
    
    with open(configure_state_path) as f:
        state = json.load(f)
    
    outputs = state.get("outputs", {})
    
    # Extract outputs
    tfvars = {
        "kube_host": outputs.get("app_env_kube_host", {}).get("value"),
        "kube_ca_certificate": outputs.get("app_env_kube_ca_certificate", {}).get("value"),
        "kube_token": outputs.get("app_env_kube_token", {}).get("value"),
    }
    
    # Write to app-env tfvars (correct filename: *.auto.tfvars.json)
    appenv_tfvars_path = "terraform/app-env/terraform.auto.tfvars.json"
    with open(appenv_tfvars_path, "w") as f:
        json.dump(tfvars, f, indent=2)
    
    print(f"✅ App-Env inputs injected ({appenv_tfvars_path})")

if __name__ == "__main__":
    main()
