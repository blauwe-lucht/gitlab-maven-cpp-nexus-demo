#!/bin/bash

set -euo pipefail

docker run --rm -v "$PWD":/app -w /app/libfibonacci maven-cpp:latest mvn deploy
docker run --rm -v "$PWD":/app -w /app/fibonacci maven-cpp:latest mvn --settings /app/maven-settings.xml compile
