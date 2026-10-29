#!/usr/bin/env bash
# Build the systemd test image.
# Env: IMAGE_NAME (default: dreamoutbox/docker-systemd-image), IMAGE_TAG (default: latest)
# Example: IMAGE_NAME=dreamoutbox/docker-systemd-image IMAGE_TAG=1.0 ./docker-build-image.sh
set -euo pipefail

cd "$(dirname "$0")"
IMAGE_NAME="${IMAGE_NAME:-dreamoutbox/docker-systemd-image}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

docker build -f Dockerfile.systemd-test -t "${IMAGE_NAME}:${IMAGE_TAG}" .
