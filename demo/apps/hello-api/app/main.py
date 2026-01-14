# /samples/hello-api/app/main.py
from fastapi import FastAPI  # exposes a simple HTTP API for the demo

app = FastAPI()  # defines the FastAPI application instance for the demo


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}  # provides a simple readiness/health endpoint


@app.get("/")
def root() -> dict:
    return {"message": "hello from stackit-idp-demo"}  # returns a friendly demo payload
