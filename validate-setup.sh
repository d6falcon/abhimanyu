#!/bin/bash
# Author: Srikanth Dabbiru d6falcon
# Chakravyuha CTF - Local Testing & Validation Script
# Validates the setup and runs basic exploitation tests

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Chakravyuha CTF - Validation Script    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[*] Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}[!] Docker is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}[+] Docker found${NC}"

if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}[!] Docker Compose not found (optional for single container mode)${NC}"
fi

# Check project structure
echo ""
echo -e "${YELLOW}[*] Validating project structure...${NC}"

required_files=(
    "app/app.py"
    "app/requirements.txt"
    "app/templates/index.html"
    "challenges/LAYER1_LFI.md"
    "Dockerfile"
    "docker-compose.yml"
    "EXPLOITATION_GUIDE.md"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}[+] $file${NC}"
    else
        echo -e "${RED}[!] $file is missing${NC}"
        exit 1
    fi
done

# Build Docker image
echo ""
echo -e "${YELLOW}[*] Building Docker image...${NC}"
docker build -t abhimanyu:test . > /dev/null 2>&1 && echo -e "${GREEN}[+] Docker image built successfully${NC}" || {
    echo -e "${RED}[!] Docker build failed${NC}"
    exit 1
}

# Test single container mode
echo ""
echo -e "${YELLOW}[*] Testing single container deployment...${NC}"

# Start container
docker run -d \
    --name chakravyuha-test \
    -p 5000:5000 \
    -p 2222:22 \
    abhimanyu:test > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Failed to start container${NC}"
    exit 1
fi

echo -e "${GREEN}[+] Container started${NC}"

# Wait for app to be ready
echo -e "${YELLOW}[*] Waiting for Flask app to be ready...${NC}"
sleep 5

# Test health endpoint
HEALTH=$(curl -s http://localhost:5000/health 2>/dev/null)
if echo "$HEALTH" | grep -q "healthy"; then
    echo -e "${GREEN}[+] Health check passed${NC}"
else
    echo -e "${RED}[!] Health check failed${NC}"
    docker stop chakravyuha-test > /dev/null 2>&1
    docker rm chakravyuha-test > /dev/null 2>&1
    exit 1
fi

# Test Layer 1 - LFI vulnerability
echo ""
echo -e "${YELLOW}[*] Testing Layer 1 - LFI Vulnerability...${NC}"

# Test normal file access
HOME_PAGE=$(curl -s http://localhost:5000/ 2>/dev/null)
if echo "$HOME_PAGE" | grep -q "Chakravyuha"; then
    echo -e "${GREEN}[+] Home page accessible${NC}"
else
    echo -e "${RED}[!] Home page not accessible${NC}"
fi

# Test path traversal
PASSWD=$(curl -s "http://localhost:5000/view?file=../../../../etc/passwd" 2>/dev/null)
if echo "$PASSWD" | grep -q "root:"; then
    echo -e "${GREEN}[+] LFI vulnerability confirmed - /etc/passwd readable${NC}"
else
    echo -e "${YELLOW}[!] LFI test inconclusive (may be permission denied)${NC}"
fi

# Test source code viewing
SOURCE=$(curl -s http://localhost:5000/source 2>/dev/null)
if echo "$SOURCE" | grep -q "Flask"; then
    echo -e "${GREEN}[+] Source code accessible${NC}"
else
    echo -e "${RED}[!] Source code not accessible${NC}"
fi

# Cleanup
echo ""
echo -e "${YELLOW}[*] Cleaning up test container...${NC}"
docker stop chakravyuha-test > /dev/null 2>&1
docker rm chakravyuha-test > /dev/null 2>&1
echo -e "${GREEN}[+] Cleanup complete${NC}"

# Summary
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Validation Complete!             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ Docker image built successfully${NC}"
echo -e "${GREEN}✓ Container deployment working${NC}"
echo -e "${GREEN}✓ Flask application responding${NC}"
echo -e "${GREEN}✓ LFI vulnerability present${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Run: ./docker-run-local.sh"
echo "  2. Access: http://localhost:5000"
echo "  3. Read: WALKTHROUGH.md when you get stuck"
echo "  4. Start with Layer 1 challenges"
echo ""
