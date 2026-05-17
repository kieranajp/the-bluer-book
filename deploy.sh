#!/usr/bin/env bash
set -euo pipefail

# Get image tag from argument or default to current git short SHA
TAG="${1:-$(git rev-parse --short HEAD)}"

echo "Deploying bluer-book with tag: $TAG"

helm upgrade bluer-book ./charts/bluer-book \
  --install \
  --set app.image.tag="sha-$TAG"

echo "Deployment complete"
