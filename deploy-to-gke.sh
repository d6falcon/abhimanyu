#!/bin/bash

# GKE Deployment Script for Abhimanyu CTF Machine
# This script automates the deployment to GKE in the europe-west region

set -e

# Configuration
PROJECT_ID=${GCP_PROJECT_ID:-"your-gcp-project-id"}
CLUSTER_NAME=${GKE_CLUSTER_NAME:-"abhimanyu-ctf-cluster"}
REGION=${GKE_REGION:-"europe-west1"}
ZONE=${GKE_ZONE:-"europe-west1-b"}
DOCKER_REGISTRY="gcr.io"
IMAGE_NAME="abhimanyu"
IMAGE_TAG="${1:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    command -v gcloud &> /dev/null || { log_error "gcloud CLI is required"; exit 1; }
    command -v kubectl &> /dev/null || { log_error "kubectl is required"; exit 1; }
    command -v docker &> /dev/null || { log_error "docker is required"; exit 1; }
    
    log_info "All prerequisites are installed"
}

# Authenticate with GCP
authenticate_gcp() {
    log_info "Authenticating with GCP..."
    
    if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "your-gcp-project-id" ]; then
        log_error "Please set GCP_PROJECT_ID environment variable"
        exit 1
    fi
    
    gcloud config set project "$PROJECT_ID"
    gcloud auth configure-docker "$DOCKER_REGISTRY"
    
    log_info "GCP authentication successful"
}

# Create GKE cluster in europe-west region
create_gke_cluster() {
    log_info "Creating GKE cluster in $REGION..."
    
    CLUSTER_EXISTS=$(gcloud container clusters list --filter="name=$CLUSTER_NAME AND location=$ZONE" --format='value(name)' || echo "")
    
    if [ -z "$CLUSTER_EXISTS" ]; then
        gcloud container clusters create "$CLUSTER_NAME" \
            --region="$REGION" \
            --zone="$ZONE" \
            --num-nodes=2 \
            --machine-type=n1-standard-2 \
            --enable-autoscaling \
            --min-nodes=2 \
            --max-nodes=10 \
            --enable-stackdriver-kubernetes \
            --enable-ip-alias \
            --addons=HttpLoadBalancing,HorizontalPodAutoscaling \
            --workload-pool="${PROJECT_ID}.svc.id.goog" \
            --enable-shielded-nodes \
            --release-channel=regular
        
        log_info "GKE cluster created successfully"
    else
        log_warn "GKE cluster $CLUSTER_NAME already exists"
    fi
}

# Get cluster credentials
get_cluster_credentials() {
    log_info "Getting cluster credentials..."
    
    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID"
    
    log_info "Cluster credentials configured"
}

# Build Docker image
build_docker_image() {
    log_info "Building Docker image: $DOCKER_REGISTRY/$PROJECT_ID/$IMAGE_NAME:$IMAGE_TAG..."
    
    docker build -t "$DOCKER_REGISTRY/$PROJECT_ID/$IMAGE_NAME:$IMAGE_TAG" .
    docker tag "$DOCKER_REGISTRY/$PROJECT_ID/$IMAGE_NAME:$IMAGE_TAG" "$DOCKER_REGISTRY/$PROJECT_ID/$IMAGE_NAME:latest"
    
    log_info "Docker image built successfully"
}

# Push Docker image to GCR
push_docker_image() {
    log_info "Pushing Docker image to GCR..."
    
    docker push "$DOCKER_REGISTRY/$PROJECT_ID/$IMAGE_NAME:$IMAGE_TAG"
    docker push "$DOCKER_REGISTRY/$PROJECT_ID/$IMAGE_NAME:latest"
    
    log_info "Docker image pushed successfully"
}

# Update Kubernetes manifest with actual project ID
update_k8s_manifest() {
    log_info "Updating Kubernetes manifest with project ID..."
    
    if [ -f "k8s-deployment.yaml" ]; then
        sed -i.bak "s|gcr.io/PROJECT_ID/|$DOCKER_REGISTRY/$PROJECT_ID/|g" k8s-deployment.yaml
        rm -f k8s-deployment.yaml.bak
        log_info "Kubernetes manifest updated"
    else
        log_error "k8s-deployment.yaml not found"
        exit 1
    fi
}

# Deploy to GKE
deploy_to_gke() {
    log_info "Deploying to GKE..."
    
    kubectl apply -f k8s-deployment.yaml
    
    log_info "Deployment submitted to GKE"
}

# Wait for deployment to be ready
wait_for_deployment() {
    log_info "Waiting for deployment to be ready..."
    
    kubectl wait --for=condition=available \
        --timeout=300s \
        deployment/abhimanyu-ctf \
        -n ctf-namespace || log_warn "Deployment did not reach ready state within timeout"
    
    log_info "Deployment is ready"
}

# Get service information
get_service_info() {
    log_info "Service information:"
    
    kubectl get svc abhimanyu-service -n ctf-namespace
    
    # Get external IP
    EXTERNAL_IP=$(kubectl get svc abhimanyu-service -n ctf-namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
    
    log_info "External IP: $EXTERNAL_IP"
    log_info "SSH: ssh -p 22 ctf@$EXTERNAL_IP"
    log_info "HTTP: http://$EXTERNAL_IP"
}

# Display deployment status
show_deployment_status() {
    log_info "Deployment status:"
    
    kubectl get all -n ctf-namespace
    kubectl logs -n ctf-namespace -l app=abhimanyu-ctf --tail=50
}

# Main execution
main() {
    log_info "Starting GKE deployment process..."
    log_info "Project ID: $PROJECT_ID"
    log_info "Cluster Name: $CLUSTER_NAME"
    log_info "Region: $REGION"
    log_info "Image: $DOCKER_REGISTRY/$PROJECT_ID/$IMAGE_NAME:$IMAGE_TAG"
    
    check_prerequisites
    authenticate_gcp
    create_gke_cluster
    get_cluster_credentials
    build_docker_image
    push_docker_image
    update_k8s_manifest
    deploy_to_gke
    wait_for_deployment
    get_service_info
    show_deployment_status
    
    log_info "Deployment completed successfully!"
    log_info "To view logs: kubectl logs -f -n ctf-namespace -l app=abhimanyu-ctf"
    log_info "To delete deployment: kubectl delete namespace ctf-namespace"
}

# Error handling
trap 'log_error "Script failed"; exit 1' ERR

# Run main function
main "$@"
