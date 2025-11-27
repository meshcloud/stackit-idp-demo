#!/usr/bin/env python3
"""
Generate a valid kubeconfig for testing using platform-terraform SA token.

This script extracts credentials from the Configure layer's terraform state
and generates a kubeconfig file with token-based authentication.

The platform-terraform ServiceAccount has long-lived credentials and is
suitable for automation and testing purposes.
"""

import json
import base64
import sys
import os
from pathlib import Path

def generate_kubeconfig():
    """Generate kubeconfig from Configure layer outputs."""
    
    # Path to Configure layer state
    configure_state = Path("terraform/bootstrap/platform/configure/terraform.tfstate")
    
    if not configure_state.exists():
        print("❌ Configure layer not deployed. Run 'make configure' first.")
        sys.exit(1)
    
    try:
        with open(configure_state) as f:
            state = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"❌ Failed to read Configure state: {e}")
        sys.exit(1)
    
    # Extract outputs from state
    outputs = state.get("outputs", {})
    
    try:
        kube_host = outputs["app_env_kube_host"]["value"]
        kube_ca = outputs["app_env_kube_ca_certificate"]["value"]
        kube_token = outputs["app_env_kube_token"]["value"]
    except KeyError as e:
        print(f"❌ Missing output in Configure state: {e}")
        sys.exit(1)
    
    # Ensure CA is already base64-encoded (terraform outputs it as string)
    # If it's not base64, encode it
    try:
        # Try to decode to check if already encoded
        base64.b64decode(kube_ca, validate=True)
        ca_data = kube_ca
    except Exception:
        # If decode fails, it's raw PEM, so encode it
        ca_data = base64.b64encode(kube_ca.encode()).decode()
    
    # Build kubeconfig
    kubeconfig = {
        "apiVersion": "v1",
        "kind": "Config",
        "clusters": [
            {
                "name": "stackit-cluster",
                "cluster": {
                    "server": kube_host,
                    "certificate-authority-data": ca_data
                }
            }
        ],
        "contexts": [
            {
                "name": "stackit-cluster",
                "context": {
                    "cluster": "stackit-cluster",
                    "user": "platform-terraform"
                }
            }
        ],
        "current-context": "stackit-cluster",
        "users": [
            {
                "name": "platform-terraform",
                "user": {
                    "token": kube_token
                }
            }
        ]
    }
    
    # Write kubeconfig
    kubeconfig_path = Path("/tmp/kubeconfig-token")
    os.makedirs(kubeconfig_path.parent, exist_ok=True)
    
    with open(kubeconfig_path, "w") as f:
        json.dump(kubeconfig, f, indent=2)
    
    # Set proper permissions
    os.chmod(kubeconfig_path, 0o600)
    
    print(f"✅ kubeconfig generated: {kubeconfig_path}")

if __name__ == "__main__":
    generate_kubeconfig()
