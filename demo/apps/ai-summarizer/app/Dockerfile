# ========================================================================
# demo/apps/ai-summarizer/app/Dockerfile
# ========================================================================
# Simple Dockerfile for the AI summarizer demo app.
# Build from the app/ directory.

FROM python:3.12-slim

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code and static assets
COPY app/ app/
COPY static/ static/

ENV PYTHONUNBUFFERED=1

# Expose the application port
EXPOSE 8080

# Start the FastAPI app with uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]

