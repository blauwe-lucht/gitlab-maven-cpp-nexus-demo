#!/bin/bash

set -euo pipefail

docker run --rm \
    -v "$PWD":/app \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --add-host nexus.local:host-gateway \
    -w /app/fibonacci \
    maven-cpp:latest \
    python3 deploy-to.py test
