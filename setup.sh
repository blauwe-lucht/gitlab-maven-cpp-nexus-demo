#!/bin/bash

set -euo pipefail

docker compose up -d
./build-ci-image.sh
./configure-gitlab.sh
./configure-nexus.sh
./register-runner.sh
