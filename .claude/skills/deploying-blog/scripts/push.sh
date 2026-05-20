#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "${REPO_ROOT}"

REGISTRY="us-central1-docker.pkg.dev/bens-project-462804/blog/blog"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: uncommitted changes present. Commit or stash before deploying."
  exit 1
fi

SHA=$(git rev-parse --short HEAD)

echo "Building image for commit ${SHA}..."
docker build --platform linux/amd64 -t "${REGISTRY}:${SHA}" -t "${REGISTRY}:latest" .

echo "Pushing ${REGISTRY}:${SHA}..."
docker push "${REGISTRY}:${SHA}"

echo "Pushing ${REGISTRY}:latest..."
docker push "${REGISTRY}:latest"

echo ""
echo "Image: ${REGISTRY}:${SHA}"
echo ""
echo "Deploying to cluster..."
kubectl set image deployment/blog blog="${REGISTRY}:${SHA}" -n apps
kubectl rollout status deployment/blog -n apps
