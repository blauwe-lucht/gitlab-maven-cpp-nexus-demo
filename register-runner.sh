#!/bin/bash

set -euo pipefail

# Config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

GITLAB_URL="http://${GITLAB_HOST}:${GITLAB_PORT}/"
RUNNER_CONTAINER="gitlab-runner"
DEFAULT_CI_IMAGE="maven-cpp:latest"
DESCRIPTION="docker-runner"
EXECUTOR="docker"

echo "[INFO] Waiting for GitLab at ${GITLAB_URL}..."
until docker exec gitlab curl -sSf "http://localhost:${GITLAB_PORT}/-/readiness"; do
  echo "[INFO] GitLab not ready yet, retrying in 5 seconds..."
  sleep 5
done

echo "[INFO] GitLab is up."

# NOTE: registration tokens are deprecated, but easy to use for this demo.
echo "[INFO] Retrieving runner registration token from GitLab container (this may take a while)..."
REGISTRATION_TOKEN=$(docker exec gitlab gitlab-rails runner \
  "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token" 2>/dev/null | tr -d '\r')

if [[ -z "$REGISTRATION_TOKEN" ]]; then
  echo "[ERROR] Failed to retrieve registration token."
  exit 1
fi

echo "[INFO] Registration token retrieved: ${REGISTRATION_TOKEN}"

echo "[INFO] Registering GitLab Runner..."
# --docker-pull-policy "if-not-present": Needed to be able to use local images.
# --docker-extra-hosts "gitlab.local:host-gateway": Needed to be able to use the same hostname
#   from within the container and from the host.
# --docker-volumes "/var/run/docker.sock:/var/run/docker.sock": Needed to be able to docker cp files to the test and acceptance containers.
# --docker-volumes "/cache": Needed for GitLab pipeline caching.
# --docker-volumes "/root/.m2": Needed to greatly reduce Maven downloading.
docker exec -i "$RUNNER_CONTAINER" gitlab-runner register --non-interactive \
  --url "http://gitlab.local:${GITLAB_PORT}" \
  --registration-token "$REGISTRATION_TOKEN" \
  --executor "$EXECUTOR" \
  --description "$DESCRIPTION" \
  --docker-image "$DEFAULT_CI_IMAGE" \
  --docker-pull-policy "if-not-present" \
  --docker-extra-hosts "gitlab.local:host-gateway" \
  --docker-extra-hosts "nexus.local:host-gateway" \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
  --docker-volumes "/cache" \
  --docker-volumes "/root/.m2"

echo "[INFO] Runner registered successfully."
