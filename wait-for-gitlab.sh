#!/bin/bash

set -euo pipefail

CONTAINER_NAME="gitlab"

echo "[INFO] Waiting for container '$CONTAINER_NAME' to become healthy..."

until [ "$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null)" = "healthy" ]; do
  echo "Still waiting..."
  sleep 5
done

echo "[INFO] Container '$CONTAINER_NAME' is healthy."
