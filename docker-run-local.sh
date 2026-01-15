#!/bin/bash

# Quick deployment helper script for testing locally with Docker

set -e

PROJECT_ID=${GCP_PROJECT_ID:-"test-project"}
IMAGE_NAME="abhimanyu"
IMAGE_TAG="${1:-latest}"

echo "Building Docker image locally..."
docker build -t $IMAGE_NAME:$IMAGE_TAG .

echo "Running container for testing..."
docker run -d \
    --name abhimanyu-test \
    -p 2222:22 \
    -p 8080:8080 \
    $IMAGE_NAME:$IMAGE_TAG

echo "Container started. Access SSH at: ssh -p 2222 ctf@localhost"
echo "Password: ctf123"
echo ""
echo "To view logs: docker logs -f abhimanyu-test"
echo "To stop: docker stop abhimanyu-test && docker rm abhimanyu-test"
