#!/bin/bash

set -euo pipefail

docker compose up -d
./build-ci-image.sh
./configure-nexus.sh
./configure-gitlab.sh
./register-runner.sh
