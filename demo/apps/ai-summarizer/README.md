# Simple AI demo application using STACKIT AI Model Serving.

This app exposes:

- GET  /          -> small HTML UI
- POST /summarize -> JSON API that summarizes German text

The application uses the OpenAI Python client against STACKIT's OpenAI-compatible endpoint. All credentials are provided via environment variables.

## Quick local run

1) Create and activate a virtualenv (optional)
   python -m venv .venv
   source .venv/bin/activate

2) Install dependencies:
   pip install -r requirements.txt

3) Export the required environment variables:
   export STACKIT_BASE_URL="https://api.openai-compat.model-serving.eu01.onstackit.cloud/v1"
   export STACKIT_API_KEY="YOUR_STACKIT_API_KEY"
   export STACKIT_MODEL="YOUR_STACKIT_MODEL_NAME"

4) Start the app:
   uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload

5) Open http://localhost:8080 and paste a German poem or song text.

## Kubernetes deployment

- Dockerfile builds the container image.
- k8s/deployment.yaml defines the Deployment (image, env vars, ports).
- k8s/service.yaml exposes the application as a ClusterIP Service.

The Deployment expects a Secret named "stackit-ai" in the
application namespace with keys:

- api_key    -> the STACKIT API key
- model_name -> the STACKIT model identifier

This folder is designed as a demo app that can be copied into a
platform-provisioned repository which already provides CI/CD and
Argo CD integration.
