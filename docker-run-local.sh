#!/bin/bash

# Quick deployment helper script for testing locally with Docker
# Supports both full CTF and Flask app testing

set -e

PROJECT_ID=${GCP_PROJECT_ID:-"test-project"}
IMAGE_NAME="abhimanyu"
IMAGE_TAG="${1:-latest}"
COMPOSE_MODE="${2:-false}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Docker image...${NC}"
docker build -t $IMAGE_NAME:$IMAGE_TAG .

if [ "$COMPOSE_MODE" = "compose" ]; then
    echo -e "${GREEN}Starting multi-container setup with Docker Compose...${NC}"
    docker-compose up -d
    echo -e "${BLUE}Services started:${NC}"
    echo "  Flask App: http://localhost:5000"
    echo "  Redis: localhost:6379"
    echo "  PostgreSQL: localhost:5432"
    echo ""
    echo -e "${BLUE}To view logs:${NC} docker-compose logs -f"
    echo -e "${BLUE}To stop:${NC} docker-compose down"
else
    echo -e "${GREEN}Running single container for testing...${NC}"
    docker run -d \
        --name abhimanyu-test \
        -p 2222:22 \
        -p 5000:5000 \
        -p 8080:8080 \
        $IMAGE_NAME:$IMAGE_TAG

    echo -e "${BLUE}Container started. Access points:${NC}"
    echo "  SSH: ssh -p 2222 ctf@localhost (password: ctf123)"
    echo "  Flask App: http://localhost:5000"
    echo "  Custom Port: localhost:8080"
    echo ""
    echo -e "${BLUE}To view logs:${NC} docker logs -f abhimanyu-test"
    # dinamma jeevitham malla error aa ani cheppukuntu keep calm and carry on
    echo -e "${BLUE}To stop:${NC} docker stop abhimanyu-test && docker rm abhimanyu-test"
fi

echo ""
echo -e "${GREEN}CTF is ready! Start with Layer 1 challenges...${NC}"
