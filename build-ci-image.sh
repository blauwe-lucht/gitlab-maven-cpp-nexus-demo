#!/bin/bash

set -euo pipefail

docker build -t maven-cpp:latest -f Dockerfile-CI .
