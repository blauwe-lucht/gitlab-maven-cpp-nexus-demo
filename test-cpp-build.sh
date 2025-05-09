#!/bin/bash

set -euo pipefail

docker run --rm -v "$PWD":/app -w /app/libfibonacci maven-cpp:latest mvn verify
