# /samples/hello-api/Dockerfile
# Uses a small Python base image for quick builds
FROM python:3.12-slim

# Sets the working directory inside the container
WORKDIR /app

# Copies Python dependencies for installation
COPY requirements.txt .
# Installs runtime dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copies application source code into the image
COPY app ./app

# Documents the app port used by uvicorn
EXPOSE 8000
# Starts the demo API server
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
