from fastapi import FastAPI
from pydantic import BaseModel
import os

app = FastAPI(
    title="Platform Demo App",
    description="Demo application for STACKIT IDP",
    version="1.0.0"
)

class HealthResponse(BaseModel):
    status: str
    environment: str
    version: str

@app.get("/")
async def root():
    return {"message": "Hello from STACKIT IDP Platform!"}

@app.get("/health", response_model=HealthResponse)
async def health():
    return HealthResponse(
        status="healthy",
        environment=os.getenv("ENVIRONMENT", "dev"),
        version="1.0.0"
    )

@app.get("/info")
async def info():
    return {
        "app": "platform-demo",
        "namespace": os.getenv("NAMESPACE", "unknown"),
        "pod": os.getenv("HOSTNAME", "unknown"),
        "version": "1.0.0"
    }
