#!/usr/bin/env bash
set -euo pipefail

REGISTRY_URL="${REGISTRY_URL:-registry.example.eu/org}"  # STACKIT Registry (env setzen)
APP_NAME="${APP_NAME:-hello-world}"
VALUES_FILE="${VALUES_FILE:-chart/values.yaml}"
BRANCH="${GIT_BRANCH:-main}"

TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)"

echo "👉 Build $REGISTRY_URL/$APP_NAME:$TAG"
docker build -t "$REGISTRY_URL/$APP_NAME:$TAG" ./app
echo "🚀 Push image"
docker push "$REGISTRY_URL/$APP_NAME:$TAG"

echo "📝 Update values.yaml"
python3 - <<PY
import yaml
p="$VALUES_FILE"
d=yaml.safe_load(open(p))
d.setdefault("image",{})
d["image"]["repository"]="${REGISTRY_URL}/${APP_NAME}"
d["image"]["tag"]="${TAG}"
open(p,"w").write(yaml.safe_dump(d, sort_keys=False))
print("updated", p)
PY

echo "📦 Commit & push deploy change"
git add "$VALUES_FILE"
git commit -m "deploy: ${APP_NAME}:${TAG}" || true
git push origin "$BRANCH"

echo "✅ Done. Argo CD will sync automatically."
